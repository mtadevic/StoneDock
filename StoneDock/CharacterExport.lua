local _, SD = ...
-- Explicit, read-only snapshot. No background scanning, uploads or alt aggregation.
local function public(v) return not issecretvalue or not issecretvalue(v) end
local function num(v) if public(v) and type(v)=="number" and v==v and math.abs(v)<math.huge then return v end end
local function str(v) if public(v) and type(v)=="string" then return v end end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...)
    if ok and public(value) then return value end
end
local ARRAY={}
local function array() return setmetatable({},ARRAY) end
local function quote(s)
    return '"'..s:gsub('[%z\1-\31\\"]',function(c)
        if c=='"' then return '\\"' elseif c=='\\' then return '\\\\' end
        return string.format('\\u%04x',string.byte(c))
    end)..'"'
end
local function json(value,depth)
    local kind=type(value)
    if kind=="string" then return quote(value)
    elseif kind=="number" then return num(value) and tostring(value) or "null"
    elseif kind=="boolean" then return value and "true" or "false"
    elseif kind~="table" then return "null" end
    local entries,keys={},{}
    local isArray=getmetatable(value)==ARRAY
    if isArray then for i=1,#value do keys[#keys+1]=i end
    else for key in pairs(value) do keys[#keys+1]=key end table.sort(keys) end
    for _,key in ipairs(keys) do
        entries[#entries+1]=string.rep("  ",depth+1)..(isArray and "" or quote(key)..": ")..json(value[key],depth+1)
    end
    if #entries==0 then return isArray and "[]" or "{}" end
    return (isArray and "[" or "{").."\n"..table.concat(entries,",\n").."\n"..string.rep("  ",depth)..(isArray and "]" or "}")
end
local professionIDs={129,164,165,171,182,185,186,197,202,333,356,393,755,773,794}
local function professions()
    local result,seen=array(),{}
    local function add(info)
        if type(info)~="table" or not public(info) then return end
        local id=num(info.skillID) local rank=num(info.rank) local name=str(info.name)
        if not id or not name or not rank or rank<=0 or seen[id] then return end
        seen[id]=true result[#result+1]={skill_id=id,name=name,rank=rank,max_rank=num(info.maxRank),modifier=num(info.modifier)}
    end
    local api=C_SkillInfo
    if api and api.GetSkillLineInfoByID then for _,id in ipairs(professionIDs) do add(call(api.GetSkillLineInfoByID,id)) end end
    if GetProfessions and GetProfessionInfo then
        local ok,one,two,arch,fish,cook,aid=pcall(GetProfessions)
        if ok then for _,index in pairs({one,two,arch,fish,cook,aid}) do
            if num(index) then
                local success,name,_,rank,maxRank,_,_,id=pcall(GetProfessionInfo,index)
                if success then add({skillID=id,name=name,rank=rank,maxRank=maxRank}) end
            end
        end end
    end
    if api and api.GetNumSkillLines and api.GetSkillLineInfo then
        local count=num(call(api.GetNumSkillLines)) or 0
        for i=1,math.min(300,count) do
            local info=call(api.GetSkillLineInfo,i)
            if type(info)=="table" then
                for _,id in ipairs(professionIDs) do if public(info.skillID) and info.skillID==id then add(info) break end end
            end
        end
    end
    table.sort(result,function(a,b)return a.skill_id<b.skill_id end)
    return result
end
function SD:BuildCharacterInformation()
    local notes=array()
    local clientVersion,clientBuild,_,clientInterface=GetBuildInfo()
    local data={schema="stonedock.character_information",schema_version=1,addon_version=self.version,
        client={game=clientInterface==16001 and "World of Warcraft Forever" or "World of Warcraft",version=str(clientVersion),build=str(clientBuild),interface=num(clientInterface)},
        scope="current_character_only",exported_at_unix=num(call(time)),
        analysis_request="Suggest practical, legitimate ways to make gold at this character's level using its professions and resources. Separate immediate sales from farming and crafting. Explain requirements and uncertainty; do not assume current auction prices or access to other characters.",
        privacy={character_name_included=false,chat_included=false,other_characters_included=false,guild_bank_included=false,warbank_included=false},
        character={level=num(call(UnitLevel,"player")),class=str(call(UnitClass,"player")),race=str(call(UnitRace,"player")),
            faction=str(call(UnitFactionGroup,"player")),realm=str(call(GetRealmName)),zone=str(call(GetRealZoneText)),subzone=str(call(GetSubZoneText)),
            money_copper=num(call(GetMoney)),xp=num(call(UnitXP,"player")),xp_to_next_level=num(call(UnitXPMax,"player"))},
        professions=professions(),bags={items=array(),free_slots=0,total_slots=0,source="live_equipped_bags"},equipment=array(),
        tsm={available=type(TSM_API)=="table",bank={items=array()},mail={items=array()},auctions={items=array()}},limitations=notes}
    if self.GetConsumableSpec then
        local _,_,spec,role=self:GetConsumableSpec() data.character.specialization=str(spec) data.character.role=str(role)
    end
    local missing=0
    local function item(id,key)
        local out={item_id=id,tsm_item_string=key or ("i:"..id)}
        local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
        if fn then
            local ok,name,_,quality,level,required,kind,subkind,_,slot,_,vendor=pcall(fn,id)
            if ok then
                out.name=str(name) out.quality=num(quality) out.item_level=num(level) out.required_level=num(required)
                out.item_type=str(kind) out.item_subtype=str(subkind) out.equip_location=str(slot) out.vendor_price_each_copper=num(vendor)
            end
        end
        if not out.name and TSM_API then out.name=str(call(TSM_API.GetItemName,out.tsm_item_string)) end
        if not out.name then missing=missing+1 out.name_status="not_cached" end
        if TSM_API and TSM_API.GetCustomPriceValue then
            out.tsm_dbmarket_each_copper=num(call(TSM_API.GetCustomPriceValue,"dbmarket",out.tsm_item_string))
            out.tsm_minbuyout_each_copper=num(call(TSM_API.GetCustomPriceValue,"dbminbuyout",out.tsm_item_string))
        end
        return out
    end
    local bagMap={}
    local container=C_Container
    if container and container.GetContainerNumSlots and container.GetContainerItemInfo then
        for bag=0,math.min(8,NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
            local slots=num(call(container.GetContainerNumSlots,bag)) or 0
            data.bags.total_slots=data.bags.total_slots+slots
            for slot=1,math.min(200,slots) do
                local info=call(container.GetContainerItemInfo,bag,slot)
                if type(info)=="table" then
                    local id=num(info.itemID) local count=num(info.stackCount)
                    if id and count and count>0 then
                        local row=bagMap[id]
                        if not row then row=item(id) row.count=0 row.bound_count=0 row.unbound_count=0 row.binding_unknown_count=0 bagMap[id]=row end
                        row.count=row.count+count
                        local bound=info.isBound
                        if not public(bound) or bound==nil then row.binding_unknown_count=row.binding_unknown_count+count
                        elseif bound then row.bound_count=row.bound_count+count
                        else row.unbound_count=row.unbound_count+count end
                    end
                end
            end
            data.bags.free_slots=data.bags.free_slots+(num(call(container.GetContainerNumFreeSlots,bag)) or 0)
        end
        for _,row in pairs(bagMap) do data.bags.items[#data.bags.items+1]=row end
        table.sort(data.bags.items,function(a,b)return a.item_id<b.item_id end)
    else notes[#notes+1]="Live bag APIs unavailable; bag contents omitted." end
    for slot=1,19 do
        local id=num(call(GetInventoryItemID,"player",slot))
        if id then local row=item(id) row.slot=slot data.equipment[#data.equipment+1]=row end
    end
    -- TSM's public per-location API defaults to the current character. Its installed
    -- v4 cache schema supplies candidate keys, from ONE exact character scope only.
    -- Never enumerate database scopes, guild/warbank records or alt totals.
    local name=str(call(UnitName,"player"))
    local faction,realm=data.character.faction,data.character.realm
    local _,_,_,interface=GetBuildInfo()
    if interface==16001 then
        local ok,first,surname=pcall(UnitName,"player")
        if ok and str(first) and str(surname) then
            local sep=Constants and Constants.CharacterNameSeparatorConsts and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR
            name=str(sep) and (first..sep..surname) or nil
        end
        local rules=Enum and Enum.GameRule
        if C_GameRules and C_GameRules.IsGameRuleActive and rules then
            local function rule(key) return rules[key] and call(C_GameRules.IsGameRuleActive,rules[key]) end
            local rp,pvp=rule("RPRuleset"),rule("PvPRuleset")
            if rule("HardcoreRuleset") then realm="Hardcore"
            elseif rp and pvp then realm="Roleplay PvP" elseif rp then realm="Roleplay"
            elseif pvp then realm="PvP" else realm="Normal" end
        end
    end
    data.tsm.market_context=str(realm)
    local db=type(TradeSkillMasterDB)=="table" and TradeSkillMasterDB
    local scope=name and faction and realm and ("s@"..name.." - "..faction.." - "..realm.."@internalData@")
    for _,spec in ipairs({{"bank","bankQuantity","GetBankQuantity"},{"mail","mailQuantity","GetMailQuantity"},{"auctions","auctionQuantity","GetAuctionQuantity"}}) do
        local section=data.tsm[spec[1]]
        local cache=db and scope and db[scope..spec[2]]
        local api=TSM_API and TSM_API[spec[3]]
        section.source="TSM_current_character_cache" section.age="unknown"
        if type(cache)=="table" and type(api)=="function" then
            section.status="cached_snapshot" local examined=0 local omitted=0
            for key in pairs(cache) do
                examined=examined+1
                if examined>1000 then section.truncated=true break end
                local id=str(key) and tonumber(key:match("^i:(%d+)"))
                if id then
                    local quantity=num(call(api,key)) -- No character/factionrealm args: current character only.
                    if quantity and quantity>0 then local row=item(id,key) row.count=quantity section.items[#section.items+1]=row end
                else omitted=omitted+1 end
            end
            section.unsupported_keys_omitted=omitted
            table.sort(section.items,function(a,b)return a.tsm_item_string<b.tsm_item_string end)
        else section.status="unavailable" end
    end
    if #data.professions==0 then notes[#notes+1]="No profession ranks returned. This may mean none are learned or the profession APIs are unavailable; do not assume no professions." end
    if missing>0 then notes[#notes+1]=missing.." item records lack cached names; IDs are included. Re-export after the client has loaded item information." end
    notes[#notes+1]="TSM cache age is unknown. Visit the bank, mailbox and auction house with TSM enabled to refresh those snapshots. Unavailable does not mean empty. TSM cache-schema changes may make these sections unavailable."
    notes[#notes+1]="TSM market/minimum-buyout values are cached estimates in copper, not guaranteed sale prices, sell rates or profit after fees. Missing prices are omitted."
    notes[#notes+1]="Bag items are aggregated by base item ID; enchantments and random variants are not differentiated. Known recipes, bank binding and quest completion are not exported."
    return data
end
function SD:ExportCharacterInformation()
    if self:IsBusy() then SD.Print("Export character information outside combat and Edit Mode.") return end
    local result=self:BuildCharacterInformation()
    self:ShowCopyDialog("Character information - JSON",json(result,0))
    self:RecordUsage("action","Export character information")
end
