local _, SD = ...
-- Current-character observations only; never buys, learns, changes filters or scans remote units.
local active={trainer=false,vendor=false}
local pending={}
local function clean(v) if (not issecretvalue or not issecretvalue(v)) and type(v)=="string" then return v:sub(1,240) end end
local function num(v) if (not issecretvalue or not issecretvalue(v)) and type(v)=="number" and v==v and math.abs(v)<math.huge then return v end end
local function boolean(v)
    if issecretvalue and issecretvalue(v) then return end
    if v==true or v==1 then return true elseif v==false then return false end
end
local function read(fn,...)
    if type(fn)~="function" then return end
    local values={pcall(fn,...)}
    if not values[1] then return end
    return unpack(values,2)
end
local function context()
    local guid=clean(read(UnitGUID,"npc"))
    local id=guid and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    local name=boolean(read(UnitIsPlayer,"npc"))==false and clean(read(UnitName,"npc")) or nil
    return {npc_id=id,name=name,zone=clean(read(GetRealZoneText)),observed_at_unix=num(read(time))}
end
local function store(kind,snapshot)
    if not StoneDockCharDB then return end
    StoneDockCharDB.economicObservations=StoneDockCharDB.economicObservations or {}
    local rows=StoneDockCharDB.economicObservations[kind] or {}
    StoneDockCharDB.economicObservations[kind]=rows
    local key=snapshot.npc_id and tostring(snapshot.npc_id) or ((snapshot.name or "unknown")..":"..(snapshot.zone or "unknown"))
    for i=#rows,1,-1 do if rows[i].key==key then table.remove(rows,i) end end
    snapshot.key=key rows[#rows+1]=snapshot
    if #rows>8 then table.remove(rows,1) end
end
function SD:CaptureEconomicTrainer()
    if not active.trainer or not self.db or self.db.economicObservations==false or InCombatLockdown() then return end
    local count=num(read(GetNumTrainerServices))
    if not count then return end
    local snapshot=context() snapshot.services={} snapshot.coverage="currently_displayed_trainer_services"
    snapshot.available_filter=boolean(read(GetTrainerServiceTypeFilter,"available"))
    snapshot.unavailable_filter=boolean(read(GetTrainerServiceTypeFilter,"unavailable"))
    snapshot.truncated=count>200 or nil
    for i=1,math.min(count,200) do
        local name,kind,_,level,subtext=read(GetTrainerServiceInfo,i)
        name,kind=clean(name),clean(kind)
        if name and (kind=="available" or kind=="unavailable" or kind=="used") then
            local skill,rank=read(GetTrainerServiceSkillReq,i)
            local row={name=name,status=kind,learned=kind=="used",required_level=num(level),subtext=clean(subtext),
                required_skill=clean(skill),required_skill_rank=num(rank),training_cost_copper=num(read(GetTrainerServiceCost,i)),
                spell_id=num(read(GetTrainerServiceSpellID,i)),ability_requirements={}}
            local requirements=num(read(GetTrainerServiceNumAbilityReq,i)) or 0
            for j=1,math.min(requirements,20) do
                local ability,met=read(GetTrainerServiceAbilityReq,i,j)
                if clean(ability) then row.ability_requirements[#row.ability_requirements+1]={name=clean(ability),met=boolean(met)} end
            end
            row.recipe_id_status=row.spell_id and "native_service_spell_id" or "not_exposed; do not infer from name"
            snapshot.services[#snapshot.services+1]=row
        end
    end
    store("trainers",snapshot)
end
function SD:CaptureEconomicVendor()
    if not active.vendor or not self.db or self.db.economicObservations==false or InCombatLockdown() then return end
    local count=num(read(GetMerchantNumItems))
    if not count then return end
    local snapshot=context() snapshot.items={} snapshot.coverage="currently_displayed_vendor_items" snapshot.truncated=count>200 or nil
    for i=1,math.min(count,200) do
        local name,_,price,bundle,stock,_,extended=read(GetMerchantItemInfo,i)
        extended=boolean(extended)
        local link=clean(read(GetMerchantItemLink,i))
        if clean(name) then snapshot.items[#snapshot.items+1]={name=clean(name),item_id=link and tonumber(link:match("item:(%d+)")),
            price_copper_per_bundle=num(price),bundle_quantity=num(bundle),stock=num(stock),has_extended_cost=extended,
            extended_cost_status=extended==nil and "unknown" or (extended and "additional_cost_not_collected" or "none_reported")} end
    end
    store("vendors",snapshot)
end
local function queue(kind)
    if pending[kind] then return end
    pending[kind]=true
    C_Timer.After(.2,function()
        pending[kind]=nil
        SD:Run("Economic "..kind.." observation",function()
            if kind=="trainer" then SD:CaptureEconomicTrainer() else SD:CaptureEconomicVendor() end
        end)
    end)
end
SD:On("TRAINER_SHOW",function()active.trainer=true queue("trainer")end)
SD:On("TRAINER_CLOSED",function()active.trainer=false end)
for _,event in ipairs({"TRAINER_UPDATE","TRAINER_SERVICE_INFO_NAME_UPDATE"}) do SD:On(event,function()if active.trainer then queue("trainer")end end) end
SD:On("MERCHANT_SHOW",function()active.vendor=true queue("vendor")end)
SD:On("MERCHANT_CLOSED",function()active.vendor=false end)
SD:On("MERCHANT_UPDATE",function()if active.vendor then queue("vendor")end end)
