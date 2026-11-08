local _, SD = ...
local font = "Fonts\\FRIZQT__.TTF"

local function label(parent, value, size, x, y, width, color)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size or 13)
    fs:SetTextColor(unpack(color or { 0.72, 0.76, 0.80 }))
    fs:SetPoint("TOPLEFT", x, y)
    if width then fs:SetWidth(width) fs:SetJustifyH("LEFT") end
    fs:SetText(value)
    return fs
end

local function button(parent, title, x, y, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(width, 30)
    b:SetText(title)
    b:SetScript("OnClick", function() SD:Run(title, callback) end)
    return b
end

local function checkbox(parent, title, key, x, y, tooltip)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(25, 25)
    b.caption = label(b, title, 12, 29, -6, 254)
    b:SetScript("OnClick", function(self)
        SD.db[key] = self:GetChecked() == true
        SD:RefreshPanels()
    end)
    b:SetScript("OnEnter", function(self)
        if tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title)
            GameTooltip:AddLine(tooltip, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b.dbKey = key
    return b
end

function SD:CreateOptions()
    if self.options then return end
    local f = CreateFrame("Frame", "StoneDockOptions", UIParent, "BackdropTemplate")
    self.options = f
    f:SetSize(650, 650)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetBackdrop({ bgFile = "Interface\\AddOns\\StoneDock\\Media\\Stone.tga", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 256, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(0.8, 0.85, 0.92, 1)
    f:SetBackdropBorderColor(0.43, 0.50, 0.57, 1)
    label(f, "S T O N E D O C K", 23, 28, -25, 570, { 0.83, 0.86, 0.88 })
    label(f, "DARK STONE  /  BLIZZARD AT THE CORE", 11, 29, -57, 570, { 0.51, 0.59, 0.65 })
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeButton=close
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() f:Hide() end)
    label(f, "A native layout with a stone dashboard. Your current layout stays available. No action slots or keybindings are changed.", 13, 28, -89, 590)
    f.status = label(f, "", 12, 28, -135, 590, { 0.70, 0.78, 0.83 })
    button(f, "Create / activate layout", 28, -161, 220, function() SD:ActivateLayout() end)
    button(f, "Restore previous layout", 260, -161, 220, function() SD:RestoreLayout() end)
    label(f, "APPEARANCE", 11, 28, -218, 280, { 0.60, 0.67, 0.73 })
    f.checks = {
        checkbox(f, "Stone panels enabled", "enabled", 26, -241),
        checkbox(f, "Zone, gold, bags, clock & connection", "showInfo", 26, -272),
        checkbox(f, "Small panel headings", "showLabels", 26, -303),
        checkbox(f, "Preview placement guides", "showGuides", 26, -334, "Shows the artwork and labelled placeholders even before a native layout is installed. These are guides, not live unit frames."),
        checkbox(f, "Curved player health / resource HUD", "showHUD", 26, -365, "Optional curved display near your character. Native status bars handle health and resource values directly; no combat calculations or automatic decisions."),
        checkbox(f, "Arrange player, target & focus", "arrangeUnits", 336, -241),
        checkbox(f, "Arrange party & raid frames", "arrangeGroups", 336, -272),
        checkbox(f, "Arrange primary chat window", "arrangeChat", 336, -303),
        checkbox(f, "Arrange bags, menu & tracking bars", "arrangeUtility", 336, -334),
        checkbox(f, "Show the four dashboard action bars", "useExtraBars", 336, -365, "Enables Blizzard Action Bars 2, 3 and 4. The Restore button puts their previous visibility settings back."),
    }
    label(f, "Native placement choices take effect when you create or rebuild the layout.", 11, 28, -405, 590, { 0.53, 0.60, 0.66 })
    label(f, "ACCENT", 11, 28, -440, 100)
    for i, entry in ipairs({ { "Silver", "silver" }, { "Violet", "violet" }, { "Moss", "green" }, { "Bronze", "bronze" } }) do
        button(f, entry[1], 112 + (i - 1) * 123, -432, 113, function()
            SD.db.accent = entry[2]
            SD:RefreshPanels()
        end)
    end
    label(f, "PANEL HEIGHT", 11, 28, -486, 110)
    local function setDensity(value)
        if SD:IsBusy() then SD.Print("Change layout density outside combat and Edit Mode.") return end
        if SD.db.density == value then return end
        local previous = SD:GetGeometry()
        local oldDensity = SD.db.density
        SD.db.density = value
        if SD:IsOurLayoutActive() and not SD:AlignLayout(SD.db.nativeGeometry or previous) then
            SD.db.density = oldDensity
        end
        SD:RefreshPanels()
    end
    button(f, "Compact", 149, -477, 135, function() setDensity(0.85) end)
    button(f, "Standard", 295, -477, 135, function() setDensity(1) end)
    button(f, "Roomy", 441, -477, 135, function() setDensity(1.15) end)
    button(f, "Rebuild placement", 28, -535, 177, function() SD:ConfirmRebuild() end)
    button(f, "Open Blizzard Edit Mode", 216, -535, 212, function() SD:OpenEditMode() end)
    button(f, "Copy diagnostics", 439, -535, 177, function() SD:ShowReport() end)
    button(f,"Weathered Stone",28,-587,188,function()SD.db.stoneTexture="weathered"SD:RefreshPanels()end)
    button(f,"Original Stone",228,-587,188,function()SD.db.stoneTexture="classic"SD:RefreshPanels()end)
    button(f,"Carved Ruins",428,-587,188,function()SD.db.stoneTexture="carved"SD:RefreshPanels()end)
    f:SetScript("OnShow", function() f:Refresh() if SD.RefreshFading then SD:RefreshFading(true) end end)
    f:SetScript("OnHide", function() if SD.RefreshFading then SD:RefreshFading() end end)
    function f:Refresh()
        for _, b in ipairs(self.checks) do b:SetChecked(SD.db[b.dbKey]) end
        local active = SD:GetActiveLayout()
        local name = active and active.layoutName or "not ready"
        self.status:SetText("Active layout: " .. name .. "   |   v" .. SD.version)
    end
    table.insert(UISpecialFrames, "StoneDockOptions")
    f:Hide()
end

function SD:ToggleOptions(force)
    if not self.options then self:CreateOptions() end
    self.options:SetShown(force == true or not self.options:IsShown())
end

function SD:OpenEditMode()
    if InCombatLockdown() then SD.Print("Finish combat before opening Edit Mode.") return end
    if EditModeManagerFrame then
        if EditModeManagerFrame.CanEnterEditMode and not EditModeManagerFrame:CanEnterEditMode() then
            SD.Print("Blizzard Edit Mode is not available in the current game state.")
            return
        end
        self:CloseSettings()
        self.options:Hide()
        ShowUIPanel(EditModeManagerFrame)
    else SD.Print("Blizzard Edit Mode is not ready yet.") end
end

function SD:ConfirmRebuild()
    StaticPopupDialogs.STONEDOCK_REBUILD = {
        text = "Rebuild the StoneDock layout using your current panel size and placement choices? Saved XP/rep and player/target/focus placements are kept. Other StoneDock placements are rebuilt.",
        button1 = "Rebuild", button2 = "Cancel", timeout = 0,
        whileDead = true, hideOnEscape = true, preferredIndex = 3,
        OnAccept = function() SD:RebuildLayout() end,
    }
    StaticPopup_Show("STONEDOCK_REBUILD")
end

function SD:ShowCopyDialog(title, contents)
    if not self.copyDialog then
        local f = CreateFrame("Frame", "StoneDockCopyDialog", UIParent, "BackdropTemplate")
        self.copyDialog = f
        f:SetSize(650, 470)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:EnableMouse(true)
        f:SetClampedToScreen(true)
        self:StyleCard(f,false)
        f.heading = label(f, "", 17, 24, -23, 580)
        label(f, "Click the text, then Ctrl+A and Ctrl+C to copy.", 12, 24, -55, 580)
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 25, -85)
        scroll:SetPoint("BOTTOMRIGHT", -45, 55)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFont("Fonts\\ARIALN.TTF", 12, "")
        edit:SetTextColor(0.82, 0.86, 0.90)
        edit:SetWidth(565)
        edit:SetHeight(700)
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        scroll:SetScrollChild(edit)
        f.edit = edit
        button(f, "Close", 501, -425, 120, function() f:Hide() end)
        table.insert(UISpecialFrames, "StoneDockCopyDialog")
    end
    self.copyDialog.heading:SetText(title)
    self.copyDialog.edit:SetText(contents or "")
    self.copyDialog:Show()
    self.copyDialog.edit:SetFocus()
    self.copyDialog.edit:HighlightText()
end


-- Native Escape -> Settings -> AddOns entry, sharing the existing controls.
function SD:RegisterAddonSettings()
    if self.settingsCategory then return end
    local modern=Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory
    if not modern and not InterfaceOptions_AddCategory then return end
    local panel=CreateFrame("Frame",nil,UIParent)
    panel.name="StoneDock"
    label(panel,"StoneDock",24,20,-20,550)
    label(panel,"Dark stone dashboard, native Blizzard frames. All configuration lives in one window with tabs on the left.",13,20,-58,550)
    local function open(callback)
        if SettingsPanel and HideUIPanel then HideUIPanel(SettingsPanel) end
        if InterfaceOptionsFrame and HideUIPanel then HideUIPanel(InterfaceOptionsFrame) end
        callback()
    end
    panel.controls={
        button(panel,"Open StoneDock settings",20,-108,330,function() open(function() SD:OpenSettingsTab(SD.settingsTab or "master") end) end),
    }
    panel:Hide()
    self.settingsPanel=panel
    if modern then
        local category=Settings.RegisterCanvasLayoutCategory(panel,"StoneDock")
        Settings.RegisterAddOnCategory(category)
        self.settingsCategory=category
    else
        InterfaceOptions_AddCategory(panel)
        self.settingsCategory=panel
    end
end
SD:On("PLAYER_LOGIN",function() SD:RegisterAddonSettings() end)
