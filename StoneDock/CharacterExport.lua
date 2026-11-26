local _, SD = ...
-- Explicit, read-only snapshot. No background scanning, uploads or alt aggregation.
local function public(v) return not issecretvalue or not issecretvalue(v) end
local function num(v) if public(v) and type(v)=="number" and v==v and math.abs(v)<math.huge then return v end end
local function str(v) if public(v) and type(v)=="string" then return v end end
local function call(fn,...)
    if type(fn)~="function" then return end
    local previous=SD.actionContext
    if SD.exportingCharacter then SD.actionContext="Character export: "..(SD.characterExportStage or "data") end
    local ok,value=pcall(fn,...)
    SD.actionContext=previous
    if ok and public(value) then return value end
end
local NULL={}
local ARRAY={}
local function array() return setmetatable({},ARRAY) end
local function quote(s)
    return '"'..s:gsub('[%z\1-\31\\"]',function(c)
        if c=='"' then return '\\"' elseif c=='\\' then return '\\\\' end
        return string.format('\\u%04x',string.byte(c))
    end)..'"'
end
local function json(value,depth)
    if value==NULL then return "null" end
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
local priceSources={"dbmarket","dbrecent","dbminbuyout","dbregionmarketavg","dbregionsalerate","dbregionsoldperday","destroy","crafting"}
local function now() return num(call(time)) end
local function age(timestamp)
    local current=now()
    if current and num(timestamp) and timestamp<=current then return current-timestamp end
end
function SD:CaptureCharacterRecipes()
    if InCombatLockdown() or not StoneDockCharDB then return end
    local api=C_TradeSkillUI
    if not api or not api.GetRecipeInfo then return end
    -- Only positively identified personal profession windows are eligible.
    for _,key in ipairs({"IsTradeSkillLinked","IsTradeSkillGuild","IsNPCCrafting"}) do
        if type(api[key])~="function" then return end
        local value=call(api[key])
        if value~=false then return end
    end
    local base=call(api.GetBaseProfessionInfo)
    local skill=type(base)=="table" and num(base.professionID)
    if not skill then
        local child=call(api.GetChildProfessionInfo)
        skill=type(child)=="table" and num(child.parentProfessionID or child.professionID)
    end
    if not skill then return end
    local owned=false
    for _,info in ipairs(professions()) do if info.skill_id==skill then owned=true break end end
    if not owned then return end
    local ids=call(api.GetAllRecipeIDs)
    local coverage="all_recipe_ids_returned"
    if type(ids)~="table" then
        ids=call(api.GetFilteredRecipeIDs,{}) coverage="visible_filtered_recipes_only"
    end
    if type(ids)~="table" then return end
    StoneDockCharDB.characterExportRecipes=StoneDockCharDB.characterExportRecipes or {}
    local store=StoneDockCharDB.characterExportRecipes[skill] or {recipes={}}
    StoneDockCharDB.characterExportRecipes[skill]=store
    store.coverage=coverage store.observed_at_unix=now()
    local examined=0
    for _,id in ipairs(ids) do
        examined=examined+1 if examined>1500 then store.truncated=true break end
        if num(id) then
            local info=call(api.GetRecipeInfo,id)
            if type(info)=="table" and public(info.learned) then
                if info.learned==true then
                    local row={recipe_id=id,name=str(info.name),learned=true,observed_at_unix=now(),reagent_slots={}}
                    local schematic=call(api.GetRecipeSchematic,id,false)
                    if type(schematic)=="table" then
                        row.output_item_id=num(schematic.outputItemID)
                        row.output_quantity_min=num(schematic.quantityMin) row.output_quantity_max=num(schematic.quantityMax)
                        for index,slot in ipairs(schematic.reagentSlotSchematics or {}) do
                            if index>40 then break end
                            local entry={quantity_required=num(slot.quantityRequired),required=slot.required==true,
                                reagent_type=num(slot.reagentType),alternatives={}}
                            for j,reagent in ipairs(slot.reagents or {}) do
                                if j>20 then break end
                                local reagentID=num(reagent.itemID)
                                if reagentID then entry.alternatives[#entry.alternatives+1]={item_id=reagentID} end
                            end
                            row.reagent_slots[#row.reagent_slots+1]=entry
                        end
                        row.reagents_status="schematic_returned"
                    else row.reagents_status="unavailable" end
                    if not row.output_item_id then
                        local link=str(call(api.GetRecipeItemLink,id))
                        row.output_item_id=link and tonumber(link:match("item:(%d+)"))
                    end
                    store.recipes[id]=row
                elseif info.learned==false then store.recipes[id]=nil end
            end
        end
    end
end
local function observeSnapshot(event)
    if not StoneDockCharDB then return end
    StoneDockCharDB.characterExportObservations=StoneDockCharDB.characterExportObservations or {}
    local section=event:find("BANK") and "bank" or (event:find("MAIL") and "mail" or "auctions")
    StoneDockCharDB.characterExportObservations[section]={event=event,observed_at_unix=now()}
end
for _,event in ipairs({"BANKFRAME_OPENED","BANKFRAME_CLOSED","MAIL_SHOW","MAIL_INBOX_UPDATE","AUCTION_HOUSE_SHOW"}) do
    SD:On(event,function()observeSnapshot(event)end)
end
local recipeQueued
for _,event in ipairs({"TRADE_SKILL_SHOW","TRADE_SKILL_LIST_UPDATE"}) do
    SD:On(event,function()
        if recipeQueued or InCombatLockdown() then return end
        recipeQueued=true
        C_Timer.After(.2,function()recipeQueued=nil SD:Run("Capture character recipes",function()SD:CaptureCharacterRecipes()end)end)
    end)
end
function SD:BuildCharacterInformation(basic)
    self.characterExportStage="character and professions"
    local notes=array()
    local clientVersion,clientBuild,_,clientInterface=GetBuildInfo()
    local data={schema="stonedock.character_information",schema_version=2,addon_version=self.version,export_mode=basic and "basic" or "full",
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
    data.tsm.price_units={dbmarket="copper_per_item",dbrecent="copper_per_item",dbminbuyout="copper_per_item",
        dbregionmarketavg="copper_per_item",dbregionsalerate="fraction",dbregionsoldperday="items_per_day",destroy="copper_per_item",crafting="copper_per_item"}
    local sourceKeys=not basic and call(TSM_API and TSM_API.GetPriceSourceKeys,{})
    local registered={}
    if type(sourceKeys)=="table" then for _,key in ipairs(sourceKeys) do if str(key) then registered[key:lower()]=true end end end
    data.tsm.price_diagnostics={queried_items=0,available_values=0,unavailable_values=0,error_values=0,unsupported_values=0,
        note="TSM detection does not confirm AuctionDB data availability. No-value results may require a TSM data update or may be item/source-specific."}
    local priceCache={}
    local function prices(key)
        if priceCache[key] then return priceCache[key] end
        local values,statuses={},{}
        local counts=data.tsm.price_diagnostics counts.queried_items=counts.queried_items+1
        for _,source in ipairs(priceSources) do
            local value,status
            if basic then status="disabled_basic_mode"
            elseif not TSM_API or type(TSM_API.GetCustomPriceValue)~="function" then status="api_unavailable"
            elseif type(sourceKeys)=="table" and not registered[source] then status="unsupported_source"
            else
                local rate=source=="dbregionsalerate" or source=="dbregionsoldperday"
                -- TSM's own tooltip scales fractional sources before evaluation, then divides.
                local previous=self.actionContext
                if self.exportingCharacter then self.actionContext="Character export: TSM price "..source end
                self.characterExportStage="TSM price "..source
                local ok,result=pcall(TSM_API.GetCustomPriceValue,rate and (source.." * 1000") or source,key)
                self.actionContext=previous
                value=ok and num(result)
                if value then
                    if rate then value=value/1000 end
                    status="available"
                else status=ok and "no_value_returned" or "query_error" end
            end
            values[source]=value or NULL statuses[source]=status
            if status=="available" then counts.available_values=counts.available_values+1
            elseif status=="query_error" then counts.error_values=counts.error_values+1
            elseif status=="unsupported_source" then counts.unsupported_values=counts.unsupported_values+1
            else counts.unavailable_values=counts.unavailable_values+1 end
        end
        priceCache[key]={values=values,statuses=statuses} return priceCache[key]
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
        if not basic and not out.name and TSM_API then out.name=str(call(TSM_API.GetItemName,out.tsm_item_string)) end
        if not out.name then missing=missing+1 out.name_status="not_cached" end
        local price=prices(out.tsm_item_string)
        out.prices=price.values out.price_status=price.statuses
        if price.values.dbmarket~=NULL then out.tsm_dbmarket_each_copper=price.values.dbmarket end
        if price.values.dbminbuyout~=NULL then out.tsm_minbuyout_each_copper=price.values.dbminbuyout end
        return out
    end
    self.characterExportStage="live bags and equipment"
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
    local db=not basic and type(TradeSkillMasterDB)=="table" and TradeSkillMasterDB
    local scope=name and faction and realm and ("s@"..name.." - "..faction.." - "..realm.."@internalData@")
    self.characterExportStage="TSM inventory"
    for _,spec in ipairs({{"bank","bankQuantity","GetBankQuantity"},{"mail","mailQuantity","GetMailQuantity"},{"auctions","auctionQuantity","GetAuctionQuantity"}}) do
        local section=data.tsm[spec[1]]
        local cache=db and scope and db[scope..spec[2]]
        local api=not basic and TSM_API and TSM_API[spec[3]]
        section.source="TSM_current_character_cache" section.age="unknown"
        section.snapshot_timestamp_status="not_provided_by_TSM_cache"
        local observed=StoneDockCharDB and StoneDockCharDB.characterExportObservations and StoneDockCharDB.characterExportObservations[spec[1]]
        if type(observed)=="table" then
            section.last_observed_event=str(observed.event) section.last_observed_at_unix=num(observed.observed_at_unix)
            section.seconds_since_observed_event=age(observed.observed_at_unix)
            section.observation_note="UI event time, not a verified TSM snapshot timestamp."
        end
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
    self.characterExportStage="personal recipes"
    if not basic then self:CaptureCharacterRecipes() end
    data.known_recipes={professions=array(),coverage="observed_personal_profession_windows; may be incomplete"}
    local recipeCache=not basic and StoneDockCharDB and StoneDockCharDB.characterExportRecipes or {}
    for _,profession in ipairs(data.professions) do
        local stored=recipeCache[profession.skill_id]
        local section={skill_id=profession.skill_id,name=profession.name,recipes=array(),status="not_observed"}
        if stored then
            section.status="cached_observation" section.observed_at_unix=num(stored.observed_at_unix)
            section.age_seconds=age(stored.observed_at_unix) section.coverage=str(stored.coverage)
            section.truncated=stored.truncated or nil
            for _,row in pairs(stored.recipes or {}) do
                local copy={recipe_id=row.recipe_id,name=row.name,learned=true,output_quantity_min=row.output_quantity_min,
                    output_quantity_max=row.output_quantity_max,observed_at_unix=row.observed_at_unix,
                    reagents_status=row.reagents_status,reagent_slots=array()}
                if row.output_item_id then copy.output=item(row.output_item_id) end
                for _,slot in ipairs(row.reagent_slots or {}) do
                    local entry={quantity_required=slot.quantity_required,required=slot.required,reagent_type=slot.reagent_type,alternatives=array()}
                    for _,reagent in ipairs(slot.alternatives or {}) do entry.alternatives[#entry.alternatives+1]=item(reagent.item_id) end
                    copy.reagent_slots[#copy.reagent_slots+1]=entry
                end
                section.recipes[#section.recipes+1]=copy
            end
            table.sort(section.recipes,function(a,b)return a.recipe_id<b.recipe_id end)
        end
        data.known_recipes.professions[#data.known_recipes.professions+1]=section
    end
    if #data.professions==0 then notes[#notes+1]="No profession ranks returned. This may mean none are learned or the profession APIs are unavailable; do not assume no professions." end
    if missing>0 then notes[#notes+1]=missing.." item records lack cached names; IDs are included. Re-export after the client has loaded item information." end
    notes[#notes+1]="TSM cache age is unknown. Visit the bank, mailbox and auction house with TSM enabled to refresh those snapshots. Unavailable does not mean empty. TSM cache-schema changes may make these sections unavailable."
    notes[#notes+1]="TSM market/minimum-buyout values are cached estimates in copper, not guaranteed sale prices, sell rates or profit after fees. Missing prices are explicit null values with per-source statuses. Zero is preserved when actually returned."
    notes[#notes+1]="Bag items are aggregated by base item ID; enchantments and random variants are not differentiated. Recipe coverage is limited to observed personal profession windows; clear profession filters and open each profession before export. Recipe output ranges are not guaranteed yields. Bank binding and quest completion are not exported."
    return data
end
function SD:ExportCharacterInformation(mode)
    if self:IsBusy() then SD.Print("Export character information outside combat and Edit Mode.") return end
    self.exportingCharacter=true self.characterExportStage="starting"
    local ok,result=pcall(self.BuildCharacterInformation,self,mode=="basic")
    self.exportingCharacter=nil
    if not ok then self:ReportError("Character export: "..self.characterExportStage,result) return end
    self.characterExportStage="serialize JSON"
    local encoded,text=pcall(json,result,0)
    if not encoded then self:ReportError("Character export JSON",text) return end
    self.characterExportStage="copy dialog"
    local shown,err=pcall(self.ShowCopyDialog,self,"Character information - JSON",text,true)
    if not shown then self:ReportError("Character export copy dialog",err) return end
    self.characterExportStage="finished ("..(mode=="basic" and "basic" or "full")..")"
    self:RecordUsage("action","Export character information")
end
