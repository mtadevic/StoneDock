local addonName, SD = ...
SD.name, SD.version = addonName, "0.13.15"
SD.defaults = {
    enabled = true,
    layoutVariant = "stone",
    density = 1,
    opacity = 1,
    accent = "silver",
    gatheringEnabled = false,
    stoneTexture = "weathered",
    moduleFlags = {},
    noteRows = {},
    noteActions = {},
    showInfo = true,
    chatStyle = false,
    showLabels = true,
    showGuides = false,
    showHUD = false,
    hudScale = 1,
    hudOffsetX = 0,
    hudOffsetY = -20,
    hudGap = 208,
    hudHeight = 210,
    hudArcWidth = 48,
    hudLabels = true,
    hudTicks = true,
    hudPowerColor = true,
    hudHealthColor = "red",
    gulveigShowBagBar = false,
    tofuShowBagBar = false,
    tofuItemOffsetX = 0,
    tofuItemOffsetY = 0,
    barOffsetX = 0,
    barOffsetY = 0,
    barSpread = 0,
    barWidth = 100,
    fadeUI = false,
    fadeHUD = false,
    uiRestAlpha = 0.25,
    hudRestAlpha = 0.25,
    revealOnHover = true,
    stoneUnits = true,
    groupClassColors = true,
    attachPlayerAuras = true,
    showUtility = true,
    dockPet = true,
    petScale = 80,
    petOffsetX = -8,
    petOffsetY = 0,
    itemOverrides = {},
    itemRules = {},
    rivetActions = {},
    hearthDiscovered = {},
    splitRaid = true,
    unitSize = 100,
    groupWidth = 108,
    groupRowWidth = 100,
    groupHeight = 36,
    groupOffsetX = 0,
    groupOffsetY = 0,
    arrangeUnits = true,
    arrangeGroups = true,
    arrangeChat = true,
    arrangeUtility = true,
    useExtraBars = true,
}
SD.colors = {
    silver = { 0.57, 0.65, 0.72 },
    violet = { 0.59, 0.43, 0.78 },
    green = { 0.43, 0.65, 0.34 },
    bronze = { 0.70, 0.53, 0.31 },
}
SD.layoutName = "StoneDock - Dark Stone"
SD.listeners = {}

function SD.Copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[key] = SD.Copy(item, seen) end
    return result
end

function SD.Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

function SD.Print(message)
    local text = "|cffadbfceStoneDock|r  " .. tostring(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(text) end
end

function SD:On(event, callback)
    self.listeners[event] = self.listeners[event] or {}
    table.insert(self.listeners[event], callback)
    self.events:RegisterEvent(event)
end

function SD:ReportError(context, err)
    local detail = tostring(err)
    self.lastError = context .. ": " .. detail
    StoneDockCharDB.lastError = self.lastError
    SD.Print(context .. " could not finish. Use /stonedock report to copy the details.")
end

function SD:Run(context, callback, ...)
    local previous=self.actionContext
    local previousParent=self.parentActionContext
    self.parentActionContext=previous
    self.actionContext=context
    local ok, result, detail = pcall(callback, ...)
    self.actionContext=previous
    self.parentActionContext=previousParent
    if not ok then self:ReportError(context, result) end
    return ok, result, detail
end

function SD:IsBusy()
    if InCombatLockdown() then
        return true, "Finish combat first, then try again."
    end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        return true, "Close Blizzard Edit Mode first so its unsaved changes are kept separate."
    end
    return false
end

function SD:InitializeDB()
    StoneDockDB = type(StoneDockDB) == "table" and StoneDockDB or {}
    StoneDockCharDB = type(StoneDockCharDB) == "table" and StoneDockCharDB or {}
    for key, value in pairs(self.defaults) do
        if StoneDockDB[key] == nil then StoneDockDB[key] = SD.Copy(value) end
    end
    local db = StoneDockDB
    db.density = SD.Clamp(tonumber(db.density) or 1, 0.8, 1.2)
    db.opacity = SD.Clamp(tonumber(db.opacity) or self.defaults.opacity, 0.4, 1)
    db.hudScale = SD.Clamp(tonumber(db.hudScale) or 1, 0.6, 1.4)
    for key, bounds in pairs({unitSize={100,200},groupWidth={72,160},groupRowWidth={70,100},groupHeight={24,72},groupOffsetX={-350,700},groupOffsetY={-100,500},hudOffsetX={-600,600},hudOffsetY={-450,450},hudGap={60,500},hudHeight={140,280},hudArcWidth={32,72},tofuItemOffsetX={-500,500},tofuItemOffsetY={-180,350},barOffsetX={-100,100},barOffsetY={-15,180},barSpread={-100,100},barWidth={70,110},uiRestAlpha={0,1},hudRestAlpha={0,1}}) do
        db[key] = SD.Clamp(tonumber(db[key]) or self.defaults[key], bounds[1], bounds[2])
    end
    for _,key in ipairs({"moduleFlags","noteRows","noteActions"})do if type(db[key])~="table"then db[key]={}end end
    if type(db.itemRules)~="table" then db.itemRules={} end
    if type(db.itemOverrides)~="table" then db.itemOverrides={} end
    if type(db.hearthDiscovered)~="table" then db.hearthDiscovered={} end
    if type(db.rivetActions)~="table" then db.rivetActions={} end
    if not self.colors[db.accent] then db.accent = "silver" end
    self.db = db
    if self.InitializeProfiles then self:InitializeProfiles() end
    if self.InitializeLayoutVariant then self:InitializeLayoutVariant() end
end

SD.events = CreateFrame("Frame")
SD.events:SetScript("OnEvent", function(_, event, ...)
    local list = SD.listeners[event]
    if list then
        for _, callback in ipairs(list) do SD:Run(event, callback, ...) end
    end
end)

-- Blocked protected actions do not necessarily raise a Lua exception.
-- Keep a small deduplicated record without touching protected UI or error handlers.
function SD:RecordBlockedAction(event, addon, action)
    if not StoneDockCharDB then return end
    local function text(value)
        if issecretvalue and issecretvalue(value) then return "restricted" end
        return tostring(value or "unknown"):sub(1,180)
    end
    local records=StoneDockCharDB.blockedActions or {}
    StoneDockCharDB.blockedActions=records
    local name,operation=text(addon),text(action)
    local combat=InCombatLockdown()
    local context=self.actionContext or "Native UI / asynchronous callback"
    -- The event dispatcher is a recorder, not the original action's context.
    if context==event then context=self.parentActionContext or "Native UI / asynchronous callback" end
    local last=records[#records]
    if last and last.event==event and last.addon==name and last.action==operation and last.combat==combat and last.context==context then
        last.count=last.count+1 last.time=date("%Y-%m-%d %H:%M:%S") return
    end
    local record={event=event,addon=name,action=operation,combat=combat,context=context,count=1,time=date("%Y-%m-%d %H:%M:%S")}
    if debugstack then record.stack=debugstack(2,10,0):sub(1,2500) end
    records[#records+1]=record
    if #records>8 then table.remove(records,1) end
    if name==self.name then SD.Print("A blocked interface action was recorded. Use /stonedock report for details.") end
end
for _,event in ipairs({"ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN"}) do
    SD:On(event,function(addon,action)SD:RecordBlockedAction(event,addon,action)end)
end

SD:On("ADDON_LOADED", function(name)
    if name ~= addonName then return end
    SD:InitializeDB()
end)

SD:On("PLAYER_LOGIN", function()
    if not SD.db then SD:InitializeDB() end
    SD:CreatePanels()
    SD:CreateHUD()
    SD:CreateDocking()
    SD:CreateFading()
    SD:RefreshPanels()
    SD:CreateOptions()
    SD:StartInfoTicker()
    if EventRegistry then
        EventRegistry:RegisterCallback("EditMode.Enter", function() SD:SetEditing(true) end, SD)
        EventRegistry:RegisterCallback("EditMode.Exit", function() SD:SetEditing(false) end, SD)
    end
    if not StoneDockCharDB.welcomed then
        SD.Print("Welcome. Choose your starting layout; /stonedock opens settings later.")
        C_Timer.After(2, function() SD:PromptForLayout() end)
    end
end)

local refreshPending
local function scheduleRefresh()
    if refreshPending or not SD.db then return end
    refreshPending = true
    C_Timer.After(0.3, function()
        SD:Run("Refresh dashboard",function() SD:RefreshPanels() end)
        refreshPending = nil
    end)
end
SD:On("UI_SCALE_CHANGED", scheduleRefresh)
SD:On("DISPLAY_SIZE_CHANGED", scheduleRefresh)
SD:On("EDIT_MODE_LAYOUTS_UPDATED", scheduleRefresh)
SD:On("PLAYER_ENTERING_WORLD", scheduleRefresh)
