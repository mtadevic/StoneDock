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

local function updateBinding(state)
    if not state.owner or InCombatLockdown() then return end
    local action = state.active and state.mode == "fishing" and state.key ~= "" and "cast" or nil
    if action and state.loot then action = "loot"
    elseif action and state.channel then
        action = state.inReach and "reel" or nil
    end
    if action == state.bound then return end
    ClearOverrideBindings(state.owner)
    if action == "reel" then
        SetOverrideBinding(state.owner, true, state.key, "INTERACTTARGET")
    elseif action then
        local button = action == "cast" and "StoneDockFishingCast" or "StoneDockFishingLoot"
        SetOverrideBindingClick(state.owner, true, state.key, button, "LeftButton")
    end
    state.bound = action
end

local function refresh(state)
    updateBinding(state)
    SD:UpdateInfo()
    if SD.gatheringStatus then SD.gatheringStatus:SetText(SD:GatheringSummary()) end
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
        SD.Print(ores[id] .. (best and (": Reported in " .. best[2] .. ". Exact catch coordinates are unavailable.")
            or ": No catch locations are documented."))
        return
    end
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
    self:UpdateInfo()
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
    if mode == "fishing" and state.key == "" and GetBindingKey then
        state.key = GetBindingKey("INTERACTTARGET") or ""
    end
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
        if state.automatic and not equipped then self:StopGathering() end
        return
    end
    if equipped and self.db.enabled and self.db.gatheringEnabled and not self.fishingAutoPaused then
        self:StartGathering("fishing", true)
    end
end

function SD:BuildGatheringPanel()
    local Create, H = self:WindowBuilder("gatheringPanel")
    local page = Create("Frame", nil, UIParent)
    self.gatheringPanel = page
    page:SetSize(690, 590)
    H.text(page, "Gathering", 22, 22, -20, 640)
    H.text(page, "Track catches or materials in Field Notes. Each session starts at zero.", 13, 22, -60, 630)
    local enable = Create("CheckButton", nil, page, "UICheckButtonTemplate")
    enable:SetPoint("TOPLEFT", 22, -94)
    enable:SetChecked(self.db.gatheringEnabled)
    H.text(enable, "Enable Gathering", 13, 28, -5, 550)
    enable:SetScript("OnClick", function(button)
        SD:SetModule("gatheringEnabled", button:GetChecked() == true)
        button:SetChecked(SD.db.gatheringEnabled)
    end)
    H.text(page, "Fishing uses your Interact key by default. Enter an unbound F-key to use it instead.", 13, 22, -135, 630)
    local key = Create("EditBox", nil, page, "InputBoxTemplate")
    key:SetPoint("TOPLEFT", 27, -164)
    key:SetSize(100, 25)
    key:SetAutoFocus(false)
    key:SetMaxLetters(3)
    key:SetText(self.db.gatheringKey or "")
    H.button(page, "Save key", 141, -164, 105, function()
        if SD:IsBusy() then return end
        local value = key:GetText():upper():match("^%s*(.-)%s*$")
        local number = tonumber(value:match("^F(%d%d?)$"))
        if value ~= "" and (not number or number < 1 or number > 12 or value ~= "F" .. number) then
            SD.Print("Enter F1 through F12, or leave it blank.")
            return
        end
        if value ~= "" and GetBindingAction and GetBindingAction(value) ~= "" then
            SD.Print("Choose a key without an existing WoW binding.")
            return
        end
        SD:StopGathering()
        SD.db.gatheringKey = value
        key:ClearFocus()
        SD:UpdatePoleFishing()
        SD.Print("Fishing key saved.")
    end)
    H.button(page, "Start fishing", 22, -225, 180, function() if SD:StartGathering("fishing") then SD:CloseSettings() end end)
    H.button(page, "Track herbs, ore & skins", 215, -225, 220, function() if SD:StartGathering("materials") then SD:CloseSettings() end end)
    H.button(page, "End session", 449, -225, 165, function() SD.fishingAutoPaused = poleEquipped() SD:StopGathering() end)
    self.gatheringStatus = H.text(page, self:GatheringSummary(), 14, 22, -275, 630)
    H.text(page, "Equipping a fishing pole starts Fishing Mode automatically. If your bobber is out of interact range, right-click it normally.", 12, 22, -310, 630)
    H.text(page, "Find gathering locations", 17, 22, -365, 630)
    H.text(page, "Choose a material to find a nearby zone or start a local loop. Fish set a waypoint to a reported catch location.", 12, 22, -395, 630)
    local function dropdown(label, choices, x, y)
        local menu = Create("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
        menu:SetPoint("TOPLEFT", x, y or -440)
        menu:SetSize(190, 32)
        if menu.SetDefaultText then menu:SetDefaultText(label) end
        if menu.SetupMenu then
            menu:SetupMenu(function(_, root)
                if root.SetScrollMode then root:SetScrollMode(330) end
                for _, item in ipairs(choices) do
                    root:CreateButton(item[2], function() SD:StartOreRoute(item[1]) end)
                end
            end)
        end
    end
    dropdown("Select ore", options.ore, 22)
    dropdown("Select herb", options.herb, 220)
    dropdown("Select fish", options.fish, 418)
    dropdown("Select fishing pool", options.pool, 22, -483)
    H.button(page, "Stop loop", 220, -483, 185, function()
        SD:StopOreRoute()
        SD:UpdateInfo()
    end)
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
