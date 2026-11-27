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
        text = "Rebuild the Lazai Adept layout using your current panel size and placement choices? Saved XP/rep and player/target/focus placements are kept. Other Lazai Adept placements are rebuilt.",
        button1 = "Rebuild", button2 = "Cancel", timeout = 0,
        whileDead = true, hideOnEscape = true, preferredIndex = 3,
        OnAccept = function() SD:RebuildLayout() end,
    }
    StaticPopup_Show("STONEDOCK_REBUILD")
end
function SD:ShowCopyDialog(title, contents, manualFocus)
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
    if not manualFocus then self.copyDialog.edit:SetFocus() end
    if not manualFocus then self.copyDialog.edit:HighlightText() end
end
-- Native Escape -> Settings -> AddOns entry, sharing the existing controls.
function SD:RegisterAddonSettings()
    if self.settingsCategory then return end
    local modern=Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory
    if not modern and not InterfaceOptions_AddCategory then return end
    local panel=CreateFrame("Frame",nil,UIParent)
    panel.name="Lazai Adept"
    label(panel,"Lazai Adept",24,20,-20,550)
    label(panel,"Dark stone dashboard, native Blizzard frames. All configuration lives in one window with tabs on the left.",13,20,-58,550)
    local function open(callback)
        if SettingsPanel and HideUIPanel then HideUIPanel(SettingsPanel) end
        if InterfaceOptionsFrame and HideUIPanel then HideUIPanel(InterfaceOptionsFrame) end
        callback()
    end
    panel.controls={
        button(panel,"Open Lazai Adept settings",20,-108,330,function() open(function() SD:OpenSettingsTab(SD.settingsTab or "master") end) end),
    }
    panel:Hide()
    self.settingsPanel=panel
    if modern then
        local category=Settings.RegisterCanvasLayoutCategory(panel,"Lazai Adept")
        Settings.RegisterAddOnCategory(category)
        self.settingsCategory=category
    else
        InterfaceOptions_AddCategory(panel)
        self.settingsCategory=panel
    end
end
SD:On("PLAYER_LOGIN",function() SD:RegisterAddonSettings() end)
