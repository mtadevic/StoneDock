local _, SD = ...
local modes = { fishing = "Fishing", materials = "Herbs, Ore & Skins" }
local gatherSpells = {
    [2366]=true,[2368]=true,[2369]=true,[2371]=true,[3570]=true,[11993]=true,[1312650]=true,
    [2575]=true,[2576]=true,[2577]=true,[2578]=true,[2579]=true,[3564]=true,[10248]=true,[1264639]=true,
    [8613]=true,[8617]=true,[8618]=true,[10768]=true,[1235230]=true,[1235236]=true,
}
local function readable(value)
    return not issecretvalue or not issecretvalue(value)
end

local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return GetSpellInfo(id) end
end

local function poleEquipped()
    local id = GetInventoryItemID and GetInventoryItemID("player", 16)
    if not readable(id) or not id then return false end
    local get = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not get then return false end
    local _, _, _, _, _, class, subclass = get(id)
    return class == 2 and subclass == 20
end

local function setFishingReach(enabled)
    local c = C_CVar
    if not c or not c.GetCVar or not c.SetCVar or InCombatLockdown() then return end
    local saved = StoneDockCharDB.fishingCVars
    if enabled then
        saved = saved or {}
        StoneDockCharDB.fishingCVars = saved
        for key, target in pairs({SoftTargetInteract=3, SoftTargetInteractRange=30, SoftTargetInteractArc=2}) do
            local current = c.GetCVar(key)
            if current and not saved[key] and (tonumber(current) or 0) < target then
                local applied = tostring(target)
                c.SetCVar(key, applied)
                saved[key] = { original=current, applied=applied }
            end
        end
    elseif saved then
        for key, value in pairs(saved) do
            if tonumber(c.GetCVar(key)) == tonumber(value.applied) then c.SetCVar(key, value.original) end
        end
        StoneDockCharDB.fishingCVars = nil
    end
end

local function bobber(guid)
    return readable(guid) and type(guid) == "string"
        and guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-35591%-") ~= nil
end

local function fishingKeys(configured)
    local keys,seen={},{}
    local function add(key)
        if type(key)~="string" or key=="" or seen[key] then return end
        local action=GetBindingAction and GetBindingAction(key) or ""
        if action~="" and action~="INTERACTTARGET" then return end
        seen[key]=true keys[#keys+1]=key
    end
    if GetBindingKey then local first,second=GetBindingKey("INTERACTTARGET") add(first) add(second) end
    add(configured)
    return keys
end

local function updateBinding(state)
    if not state.owner or InCombatLockdown() then return end
    local action = state.active and state.mode == "fishing" and state.key ~= "" and "cast" or nil
    if action and state.loot then action = "loot"
    elseif action and state.channel then
        action = state.inReach and "reel" or nil
    end
    if action == state.bound then return end
    ClearOverrideBindings(state.owner)
    for _,key in ipairs(state.keys or {state.key}) do
        if action == "reel" then
            SetOverrideBinding(state.owner, true, key, "INTERACTTARGET")
        elseif action then
            local button = action == "cast" and "StoneDockFishingCast" or "StoneDockFishingLoot"
            SetOverrideBindingClick(state.owner, true, key, button, "LeftButton")
        end
    end
    state.bound = action
end

local function refresh(state)
    updateBinding(state)
    SD:UpdateInfo()
    if SD.RefreshExpeditionStatus then SD:RefreshExpeditionStatus() end
end

local function lootMatches(state)
    if state.mode == "materials" then
        return state.gatheredAt and GetTime() - state.gatheredAt < 3
    end
    if IsFishingLoot then
        local fishing = IsFishingLoot()
        if readable(fishing) and fishing then return true end
    end
    if not GetLootSourceInfo then return false end
    for slot = 1, GetNumLootItems() do
        for _, source in ipairs({ GetLootSourceInfo(slot) }) do
            if bobber(source) then return true end
        end
    end
    return false
end

local activeEvents = {
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_SUCCEEDED",
    "PLAYER_SOFT_INTERACT_CHANGED", "LOOT_READY", "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED",
}

local options = SD.foreverGatheringOptions
local ores, fishIDs = {}, {}
for _, group in pairs(options) do
    for _, item in ipairs(group) do ores[item[1]] = item[2] end
end
for _, group in ipairs({options.fish, options.pool}) do
    for _, item in ipairs(group) do fishIDs[item[1]] = true end
end

local function distance(a, b)
    return (a.x-b.x)^2 + (a.y-b.y)^2
end

local function recordOre(id, location)
    if not ores[id] or not location then return end
    local db = StoneDockCharDB
    db.oreNodes = db.oreNodes or {}
    local key = location.map .. ":" .. id
    local points = db.oreNodes[key] or {}
    db.oreNodes[key] = points
    for _, point in ipairs(points) do
        if distance(location, point) < 0.25^2 then return end
    end
    if #points < 200 then points[#points+1] = location end
end

local function worldPosition(point)
    if not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return end
    local continent, position = C_Map.GetWorldPosFromMapPos(point.map, CreateVector2D(point.x/100, point.y/100))
    if not readable(continent) or not continent or not position then return end
    local x, y = position:GetXY()
    if readable(x) and readable(y) and type(x) == "number" and type(y) == "number" then
        return continent, {x=x,y=y}
    end
end

function SD:SuggestOreZone(id, here)
    local continent, origin = worldPosition(here)
    local candidates = {}
    local function consider(key, points, flat)
        local map, ore = key:match("^(%d+):(%d+)$")
        map = tonumber(map)
        if tonumber(ore) ~= id or map == here.map or #points < (fishIDs[id] and 2 or (flat and 6 or 3)) then return end
        local candidate = candidates[map] or {map=map}
        candidates[map] = candidate
        if not origin then return end
        for i = 1, #points, flat and 2 or 1 do
            local node = flat and {map=map,x=points[i],y=points[i+1]} or points[i]
            local nodeContinent, position = worldPosition(node)
            if position and nodeContinent == continent then
                local score = distance(origin, position)
                if not candidate.score or score < candidate.score then candidate.score = score end
            end
        end
    end
    local _, _, _, interface = GetBuildInfo()
    if interface == 16001 then
        for key, points in pairs(self.foreverOreNodes) do consider(key, points, true) end
    end
    for key, points in pairs(StoneDockCharDB.oreNodes or {}) do consider(key, points, false) end
    local best, only, count
    count = 0
    for _, candidate in pairs(candidates) do
        count, only = count+1, candidate
        if candidate.score and (not best or candidate.score < best.score
            or (candidate.score == best.score and candidate.map < best.map)) then best = candidate end
    end
    local result = best or (count == 1 and only)
    if not result then return end
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(result.map)
    local fallback = {[1426]="Dun Morogh",[1432]="Loch Modan"}
    return info and info.name or fallback[result.map], best ~= nil
end

function SD:StartOreRoute(id)
    if not ores[id] then return end
    if self:IsBusy() or not self.db.gatheringEnabled then
        SD.Print("Enable Gathering and start the loop outside combat and Edit Mode.")
        return
    end
    local here = self:GetCurrentLocation()
    if not here then SD.Print("Your current zone coordinates are unavailable.") return end
    local _, _, _, interface = GetBuildInfo()
    local zones = interface == 16001 and self.foreverFishZones[id]
    if zones then
        local continent, origin = worldPosition(here)
        local best, bestDistance
        for _, zone in ipairs(zones) do
            if zone[1] == here.map or zone[2] == here.name then
                if self:StartGathering("fishing") then self.gathering.targetID,self.gathering.destination=id,zone[2] self:UpdateInfo() self:RefreshExpeditionStatus() end
                SD.Print(ores[id] .. ": Reported in " .. zone[2] .. ". Exact catch coordinates are unavailable.")
                return
            end
            if origin and zone[1] then
                local other, center = worldPosition({map=zone[1],x=50,y=50})
                if center and other == continent then
                    local score = distance(origin, center)
                    if not bestDistance or score < bestDistance then best, bestDistance = zone, score end
                end
            end
        end
        best = best or zones[1]
        if best and self:StartGathering("fishing") then self.gathering.targetID,self.gathering.destination=id,best[2] self:UpdateInfo() self:RefreshExpeditionStatus() end
        SD.Print(ores[id] .. (best and (": Reported in " .. best[2] .. ". Exact catch coordinates are unavailable.")
            or ": No catch locations are documented."))
        return
    end
    local destination = here.name
    local key = here.map .. ":" .. id
    local saved = StoneDockCharDB.oreNodes
    local remaining = {unpack(saved and saved[key] or {})}
    local reference = interface == 16001 and self.foreverOreNodes[key]
    if reference then
        for i = 1, #reference, 2 do
            local point = {map=here.map, x=reference[i], y=reference[i+1]}
            local duplicate
            for _, known in ipairs(remaining) do
                if distance(point, known) < 0.6^2 then duplicate = true break end
            end
            if not duplicate then remaining[#remaining+1] = point end
        end
    end
    if #remaining < (fishIDs[id] and 1 or 3) then
        local zone = self:SuggestOreZone(id, here)
        if zone then
            if self:StartGathering(fishIDs[id] and "fishing" or "materials") then
                self.gathering.targetID, self.gathering.destination = id, zone
                self:UpdateInfo()
                if self.RefreshExpeditionStatus then self:RefreshExpeditionStatus() end
            end
            SD.Print(ores[id] .. ": Suggested zone — " .. zone .. (fishIDs[id] and ". Select the fish again when you arrive." or ". Start the loop when you arrive."))
        elseif fishIDs[id] then
            SD.Print("No nearby reported catch location is available for " .. ores[id] .. ".")
        else
            SD.Print("This zone has fewer than three " .. ores[id] .. " locations. Record more finds to make a loop.")
        end
        return
    end
    if fishIDs[id] then
        local nearest = remaining[1]
        for i = 2, #remaining do
            if distance(here, remaining[i]) < distance(here, nearest) then nearest = remaining[i] end
        end
        if self:SetWaypoint(nearest.map, nearest.x, nearest.y) then
            if self:StartGathering("fishing") then
                self.gathering.targetID = id
                self.gathering.destination = here.name
            end
            self:StopOreRoute()
            self:UpdateInfo()
            SD.Print(ores[id] .. ": Waypoint set to a reported catch location.")
            return true
        end
        return
    end
    local route = {id=id, index=0, points={}}
    while #remaining > 0 and #route.points < 24 do
        local nearest = 1
        for i = 2, #remaining do
            if distance(here, remaining[i]) < distance(here, remaining[nearest]) then nearest = i end
        end
        here = table.remove(remaining, nearest)
        route.points[#route.points+1] = here
    end
    if not (self.gathering and self.gathering.active and self.gathering.mode == "materials") then
        if not self:StartGathering("materials") then return end
    end
    local previous = self.oreRoute
    self.oreRoute = route
    self.gathering.targetID, self.gathering.destination = id, destination
    if not self:AdvanceOreRoute() then
        self.oreRoute = previous
        return
    end
    if not self.oreRouteTicker then
        self.oreRouteTicker = C_Timer.NewTicker(0.5, function() SD:CheckOreRouteArrival() end)
    end
end

function SD:AdvanceOreRoute()
    local route = self.oreRoute
    if not route then return false end
    local nextIndex = route.index % #route.points + 1
    local point = route.points[nextIndex]
    if not self:SetWaypoint(point.map, point.x, point.y) then return false end
    route.index = nextIndex
    if nextIndex==1 then route.laps=(route.laps or -1)+1 end
    self:UpdateInfo()
    if self.RefreshExpeditionStatus then self:RefreshExpeditionStatus() end
    return true
end

function SD:CheckOreRouteArrival()
    local route = self.oreRoute
    if not route or self:IsBusy() then return end
    local point = route.points[route.index]
    local here = self:GetCurrentLocation()
    if point and here and here.map == point.map and distance(here, point) <= 0.25^2 then
        if not self:AdvanceOreRoute() then self:StopOreRoute() end
    end
end

function SD:StopOreRoute()
    self.oreRoute = nil
    if self.oreRouteTicker then
        self.oreRouteTicker:Cancel()
        self.oreRouteTicker = nil
    end
end

local function onEvent(_, event, unit, target, spell)
    local state = SD.gathering
    if not state.active then return end
    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        if state.loot then return end
        state.loot = lootMatches(state) and true or nil
        if state.loot then
            state.gatheredAt = nil
            state.slots = {}
            state.lootLocation = state.mode == "materials" and SD:GetCurrentLocation()
            for slot = 1, GetNumLootItems() do
                local _, name, quantity = GetLootSlotInfo(slot)
                if readable(name) and readable(quantity) and name and quantity
                    and (not GetLootSlotType or GetLootSlotType(slot) == 1) then
                    local link = GetLootSlotLink and GetLootSlotLink(slot)
                    local id = readable(link) and link and tonumber(link:match("item:(%d+)"))
                    state.slots[slot] = { name, quantity, id }
                end
            end
        end
    elseif event == "LOOT_SLOT_CLEARED" then
        local item = state.loot and state.slots[unit]
        if not item then return end
        state.slots[unit] = nil
        state.count = state.count + item[2]
        state.last = item[1]
        recordOre(item[3], state.lootLocation)
    elseif event == "LOOT_CLOSED" then
        state.loot, state.slots = nil, nil
    elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then
        if not state.channel then return end
        state.inReach = bobber(target)
    elseif readable(unit) and unit == "player" then
        if event == "UNIT_SPELLCAST_CHANNEL_STOP" then state.channel = false
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
            local name = readable(spell) and spell and spellName(spell)
            state.channel = state.mode == "fishing" and readable(name) and name ~= nil and name == state.fishingName
            state.inReach = state.channel and UnitGUID and bobber(UnitGUID("softinteract"))
        elseif state.mode == "materials" and readable(spell) and spell then
            local name = spellName(spell)
            if gatherSpells[spell] or (readable(name) and name and state.gatherNames[name]) then
                state.gatheredAt = GetTime()
            else
                state.gatheredAt = nil
            end
        end
    else
        return
    end
    refresh(state)
end

function SD:GatheringSummary()
    local state = self.gathering
    if not state or not state.active then return "No gathering session running." end
    return string.format("%s  |  %d items", modes[state.mode], state.count)
end

function SD:GetGatheringNotes()
    local state = self.gathering
    if not state or not state.active then return end
    local hint = "Use your normal Interact key"
    if state.mode == "fishing" then
        if state.loot then hint = "Loot the catch"
        elseif state.channel then
            hint = state.bound == "reel" and "Reel when the bobber splashes" or "Right-click the bobber when it splashes"
        else hint = "Cast Fishing" end
        if state.bound then hint = state.key .. "  |  " .. hint end
    end
    local route = self.oreRoute
    if route and route.index > 0 then
        local point = route.points[route.index]
        hint = string.format("%s %d/%d  |  %.1f, %.1f  |  Click for next", ores[route.id], route.index, #route.points, point.x, point.y)
    end
    return self:GatheringSummary(), state.last and ("Last: " .. state.last) or "Waiting for your first find", hint
end

function SD:StopGathering()
    local state = self.gathering
    if not state or not state.active then return end
    state.active = false
    self:StopOreRoute()
    state.events:UnregisterAllEvents()
    if state.mode == "fishing" then setFishingReach(false) end
    refresh(state)
end

function SD:StartGathering(mode, automatic)
    if not modes[mode] then return end
    local busy, why = self:IsBusy()
    if busy then SD.Print(why) return end
    if not self.db.enabled or not self.db.gatheringEnabled then
        SD.Print("Enable the dashboard and Gathering before starting a session.")
        return
    end
    self:StopGathering()
    local events = self.gatheringEvents or CreateFrame("Frame")
    self.gatheringEvents = events
    local state = {
        active = true, events = events, mode = mode, count = 0, automatic = automatic,
        key = self.db.gatheringKey or "", fishingName = spellName(select(4, GetBuildInfo()) < 100000 and 7620 or 131474) or spellName(7620),
    }
    self.gathering = state
    state.keys=mode=="fishing" and fishingKeys(state.key) or {}
    if mode=="fishing" then state.key=state.keys[1] or "" end
    if mode == "materials" then
        state.gatherNames = {}
        for _, id in ipairs({2366, 2575, 8613}) do
            local name = spellName(id)
            if readable(name) and name then state.gatherNames[name] = true end
        end
    end
    local binding = mode == "fishing" and state.key ~= "" and GetBindingAction and GetBindingAction(state.key) or ""
    if mode == "fishing" and state.key ~= "" and state.fishingName
        and ClearOverrideBindings and SetOverrideBinding and SetOverrideBindingClick
        and (binding == "" or binding == "INTERACTTARGET") then
        state.owner = self.fishingBindingOwner or CreateFrame("Frame")
        self.fishingBindingOwner = state.owner
        if not StoneDockFishingCast then
            local cast = CreateFrame("Button", "StoneDockFishingCast", UIParent, "SecureActionButtonTemplate")
            cast:RegisterForClicks("AnyDown")
            cast:SetAttribute("useOnKeyDown", true)
            cast:SetAttribute("type", "macro")
            local loot = CreateFrame("Button", "StoneDockFishingLoot", UIParent)
            loot:RegisterForClicks("AnyDown")
            loot:SetScript("OnClick", function()
                if InCombatLockdown() or not SD.gathering.active or not SD.gathering.loot then return end
                for slot = GetNumLootItems(), 1, -1 do LootSlot(slot) end
            end)
        end
        setFishingReach(true)
        StoneDockFishingCast:SetAttribute("macrotext", "/cast [nocombat,noflying,noswimming,nostealth,novehicleui] " .. state.fishingName)
    end
    events:SetScript("OnEvent", onEvent)
    for _, event in ipairs(activeEvents) do pcall(events.RegisterEvent, events, event) end
    if mode == "fishing" and not state.owner then
        SD.Print("Fishing started. Cast from your spellbook or assign an Interact or fishing key.")
    end
    refresh(state)
    return true
end

function SD:UpdatePoleFishing()
    if not self.db or InCombatLockdown() then return end
    local equipped = poleEquipped()
    if not equipped then self.fishingAutoPaused = nil end
    local state = self.gathering
    if state and state.active then
        if state.automatic and not equipped then self:StopGathering()
        elseif equipped and state.mode~="fishing" and self.db.enabled and self.db.gatheringEnabled and not self.fishingAutoPaused then
            self:StartGathering("fishing",true)
        end
        return
    end
    if equipped and self.db.enabled and self.db.gatheringEnabled and not self.fishingAutoPaused then
        self:StartGathering("fishing", true)
    end
end

function SD:GetExpeditionDetails()
    local state, route = self.gathering, self.oreRoute
    if not state or not state.active then
        return {active=false, title="No expedition running", status="READY TO EXPLORE",
            detail="Choose an activity and a resource, then start your expedition.", count="Your catches and materials will appear here."}
    end
    local resource = state.targetID and ores[state.targetID]
    local location = state.destination or (GetZoneText and GetZoneText()) or "Current zone"
    local progress = route and string.format("Stop %d of %d  /  Lap %d",route.index,#route.points,(route.laps or 0)+1)
    return {active=true,title=resource or modes[state.mode],status="EXPEDITION ACTIVE",
        detail=progress or (state.mode=="fishing" and "Fishing session" or "Gathering session"),
        destination=location,count=string.format("%d items collected",state.count),
        last=state.last and ("Last find: "..state.last) or "Waiting for the first find",
        progress=route and route.index/#route.points or 0}
end

function SD:RefreshExpeditionStatus()
    local view = self.gatheringStatusCard
    if not view then return end
    local info = self:GetExpeditionDetails()
    view.status:SetText(info.status)
    view.status:SetTextColor(info.active and .42 or .62,info.active and .87 or .68,info.active and .66 or .72)
    view.title:SetText(info.title)
    view.detail:SetText((info.destination and info.destination.."  |  " or "")..info.detail)
    view.count:SetText(info.count.."  |  "..(info.last or ""))
    view:SetBackdropBorderColor(info.active and .25 or .22,info.active and .63 or .30,info.active and .45 or .35,1)
    view.progress:SetWidth(math.max(1,590*(info.progress or 0)))
    if view.stop then view.stop:SetEnabled(info.active) end
    if view.start then
        local field = self.preferenceDrafts and self.preferenceDrafts.gathering
        local current = field and field.fields.gatheringMode
        local mode = current and self:PreferenceValue("gathering",current) or self.db.gatheringMode or "materials"
        view.start:SetText(info.active and "Start a new expedition" or (mode=="fishing" and "Start fishing" or "Start expedition"))
    end
end

function SD:BuildGatheringPanel()
    local modeField={key="gatheringMode",label="Activity",kind="select",rebuild=true,
        choices={{"materials","Gather materials"},{"fishing","Fish with equipped pole"},{"ore","Find ore"},{"herb","Find herbs"},{"fish","Find fish"},{"pool","Find fishing pools"}},
        read=function() return SD.db.gatheringMode or "materials" end}
    local mode=self:PreferenceValue("gathering",modeField)
    local setup={
        {key="gatheringEnabled",label="Enable Gathering & fishing",kind="check"},
        modeField,
    }
    local choices=options[mode]
    if choices then
        local resourceField={key="gatheringResource",label="Resource",kind="select",choices=choices,
            read=function()
                local id=SD.db.gatheringResource
                for _, item in ipairs(choices) do if item[1]==id then return id end end
                return choices[1][1]
            end}
        local draft=self:GetPreferenceDraft("gathering")
        local current=draft.values.gatheringResource
        if current then
            local valid
            for _, item in ipairs(choices) do if item[1]==current then valid=true break end end
            if not valid then draft.values.gatheringResource=nil end
        end
        setup[#setup+1]=resourceField
    end
    local keys={{"","Interact key only"}}
    for index=1,12 do keys[#keys+1]={"F"..index,"F"..index} end
    local definition={title="Gathering & expeditions",description="Set up an expedition below. Apply your changes before starting.",top=-285,sections={
        {title="Expedition setup",controls=setup},
        {title="Fishing controls",controls={{key="gatheringKey",label="Additional fishing key",kind="select",choices=keys,
            read=function() return SD.db.gatheringKey or "" end}}},
    }}
    local page=self:BuildPreferencePage("gathering",definition)
    self.gatheringPanel=page
    local create,H=self:WindowBuilder("expeditionSettings")
    local card=create("Frame",nil,page,"BackdropTemplate")
    self.gatheringStatusCard=card
    card:SetPoint("TOPLEFT",14,-105)card:SetSize(648,155)
    card:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    card:SetBackdropColor(.035,.085,.075,.96)
    card.status=H.text(card,"",11,18,-14,600)
    card.title=H.text(card,"",22,18,-39,600)
    card.detail=H.text(card,"",12,18,-75,600)
    card.count=H.text(card,"",12,18,-100,600)
    card.track=card.track or card:CreateTexture(nil,"BACKGROUND")
    card.track:SetPoint("TOPLEFT",18,-133)card.track:SetSize(590,4)card.track:SetColorTexture(.13,.22,.2,1)
    card.progress=card.progress or card:CreateTexture(nil,"ARTWORK")
    card.progress:SetPoint("TOPLEFT",18,-133)card.progress:SetHeight(4)card.progress:SetColorTexture(.35,.78,.57,1)
    local y=-page:GetHeight()
    card.start=H.button(page,"Start expedition",22,y,300,function()
        if SD:HasPreferenceChanges("gathering") then SD.Print("Apply your expedition setup first.") return end
        local activity=SD.db.gatheringMode or "materials"
        if activity=="fishing" or activity=="materials" then SD:StartGathering(activity)
        else
            local choices=options[activity]
            local resource=SD.db.gatheringResource
            local valid
            for _, item in ipairs(choices or {}) do if item[1]==resource then valid=true break end end
            SD:StartOreRoute(valid and resource or choices[1][1])
        end
        SD:RefreshExpeditionStatus()
    end)
    card.stop=H.button(page,"End expedition",338,y,300,function()
        SD.fishingAutoPaused=poleEquipped()
        SD:StopGathering()
        SD:RefreshExpeditionStatus()
    end)
    H.text(page,"Fishing Mode also starts when you equip a pole. Use the route card in Field Notes to skip a stop or end the expedition.",12,22,y-52,610)
    page:SetHeight(-y+115)
    self:RefreshExpeditionStatus()
    return page
end

SD:On("PLAYER_REGEN_DISABLED", function() SD:StopGathering() end)
SD:On("PLAYER_REGEN_ENABLED", function()
    if SD.gathering then updateBinding(SD.gathering) end
    setFishingReach(false)
    SD:UpdatePoleFishing()
end)
SD:On("PLAYER_LEAVING_WORLD", function() SD:StopGathering() end)

SD:On("PLAYER_ENTERING_WORLD", function()
    if not (SD.gathering and SD.gathering.active) then setFishingReach(false) end
    SD:UpdatePoleFishing()
end)
SD:On("PLAYER_EQUIPMENT_CHANGED", function(slot)
    if slot == 16 then SD:UpdatePoleFishing() end
end)
SD:On("PLAYER_LOGOUT", function() setFishingReach(false) end)

-- Binding changes rebuild only our temporary overrides, outside protected states.
SD:On("UPDATE_BINDINGS",function()
    if SD:IsBusy() then SD.fishingBindingsPending=true return end
    local state=SD.gathering
    if SD.fishingRebinding or not state or not state.active or state.mode~="fishing" then return end
    if SD.Equal(state.keys,fishingKeys(SD.db.gatheringKey)) then return end
    SD.fishingRebinding=true
    local ok,err=pcall(function()
        if SD:StartGathering("fishing",state.automatic) then
            for _,key in ipairs({"count","last","targetID","destination","channel","inReach","loot","slots"}) do SD.gathering[key]=state[key] end
            refresh(SD.gathering)
        end
    end)
    SD.fishingRebinding=nil
    if not ok then SD:ReportError("Refresh fishing bindings",err) end
end)
SD:On("PLAYER_REGEN_ENABLED",function()
    if not SD.fishingBindingsPending or SD:IsBusy() then return end
    SD.fishingBindingsPending=nil
    SD:UpdatePoleFishing()
end)
