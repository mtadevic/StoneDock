local _, SD = ...
local function text(parent, caption, size, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", size, "")
    label:SetPoint("TOPLEFT", x, y)
    label:SetTextColor(0.73, 0.79, 0.83)
    if width then label:SetWidth(width) label:SetJustifyH("LEFT") end
    label:SetText(caption)
    return label
end

local function slider(parent, caption, key, low, high, step, x, y, refresh)
    local label = text(parent, caption, 12, x, y, 275)
    local s = CreateFrame("Slider", nil, parent)
    s:SetPoint("TOPLEFT", x + 4, y - 24)
    s:SetSize(258, 14)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(low, high)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.12, 0.15, 0.19, 1)
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:GetThumbTexture():SetSize(24, 24)
    s:SetScript("OnValueChanged", function(_, value)
        value = low + math.floor((value - low) / step + 0.5) * step
        label:SetText(caption .. "  " .. string.format(step < 1 and "%.2f" or "%d", value))
        if parent.refreshing then return end
        SD.db[key] = value
        if refresh then refresh() end
    end)
    s.dbKey = key
    return s
end

local function check(parent, caption, key, x, y)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(25, 25)
    text(b, caption, 12, 29, -6, 250)
    b.dbKey = key
    b:SetScript("OnClick", function(self) SD.db[key] = self:GetChecked() == true SD:RefreshFading() end)
    return b
end

local function button(parent, caption, x, y, width, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", x, y)
    b:SetSize(width, 30)
    b:SetText(caption)
    b:SetScript("OnClick", function() SD:Run(caption, fn) end)
    return b
end

function SD:ToggleAdvanced(force)
    if not self.advanced then
        local f = CreateFrame("Frame", "StoneDockAdvanced", UIParent, "BackdropTemplate")
        self.advanced = f
        f:SetSize(680, 760)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetClampedToScreen(true)
        f:SetMovable(true) f:EnableMouse(true) f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        f:SetBackdrop({bgFile="Interface\\AddOns\\StoneDock\\Media\\Stone.tga",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=256,edgeSize=14})
        f:SetBackdropColor(0.8,0.85,0.92,1)
        text(f,"POSITION & VISIBILITY",21,28,-25,610)
        text(f,"Bars and stone wells move together. HUD adjustments preview immediately.",12,28,-62,610)
        local close = CreateFrame("Button",nil,f,"UIPanelCloseButton")
        f.closeButton=close
        close:SetPoint("TOPRIGHT",-6,-6) close:SetScript("OnClick",function() f:Hide() end)
        text(f,"ACTION BAR GROUPS",11,28,-100,280)
        text(f,"CURVED PLAYER HUD",11,358,-100,280)
        f.sliders = {
            slider(f,"Horizontal position","barOffsetX",-100,100,1,28,-128,function() SD:RefreshPanels() end),
            slider(f,"Vertical position","barOffsetY",-15,180,1,28,-189,function() SD:RefreshPanels() end),
            slider(f,"Separation from center","barSpread",-100,100,1,28,-250,function() SD:RefreshPanels() end),
            slider(f,"Bar width (%)","barWidth",70,110,1,28,-311,function() SD:RefreshPanels() end),
            slider(f,"Horizontal position","hudOffsetX",-600,600,2,358,-128,function() SD:RefreshHUD() end),
            slider(f,"Vertical position","hudOffsetY",-450,450,2,358,-189,function() SD:RefreshHUD() end),
            slider(f,"Bar separation","hudGap",60,500,2,358,-250,function() SD:RefreshHUD() end),
            slider(f,"HUD scale","hudScale",0.6,1.4,0.05,358,-311,function() SD:RefreshHUD() end),
        }
        button(f,"Apply bar alignment",28,-373,275,function() SD:AlignLayout() end)
        button(f,"Reset positions",358,-373,275,function()
            for _,key in ipairs({"barOffsetX","barOffsetY","barSpread","barWidth","hudOffsetX","hudOffsetY","hudGap","hudScale"}) do SD.db[key]=SD.defaults[key] end
            f:Refresh() SD:RefreshPanels()
        end)
        text(f,"OUT OF COMBAT",11,28,-430,610)
        f.checks = {
            check(f,"Fade the dashboard & native frames","fadeUI",26,-454),
            check(f,"Fade the curved player HUD","fadeHUD",356,-454),
            check(f,"Reveal dashboard on mouse-over","revealOnHover",26,-560),
        }
        table.insert(f.sliders,slider(f,"Dashboard opacity","uiRestAlpha",0,1,0.05,28,-493,function() SD:RefreshFading() end))
        table.insert(f.sliders,slider(f,"HUD opacity","hudRestAlpha",0,1,0.05,358,-493,function() SD:RefreshFading() end))
        text(f,"0 = invisible; 1 = fully visible. Combat restores both groups immediately. Open settings keep controls visible while you adjust them.",12,28,-606,610)
        button(f,"Back to appearance",28,-688,275,function() f:Hide() SD:ToggleOptions(true) end)
        button(f,"Close & preview fading",358,-688,275,function() SD:CloseSettings() SD:RefreshFading() end)
        function f:Refresh()
            self.refreshing=true
            for _,s in ipairs(self.sliders) do s:SetValue(SD.db[s.dbKey]) end
            for _,b in ipairs(self.checks) do b:SetChecked(SD.db[b.dbKey]) end
            self.refreshing=nil
        end
        f:SetScript("OnShow",function() f:Refresh() SD:RefreshFading(true) end)
        f:SetScript("OnHide",function() SD:RefreshFading() end)
        table.insert(UISpecialFrames,"StoneDockAdvanced")
        f:Hide()
    end
    if self.options then self.options:Hide() end
    self.advanced:SetShown(force==true or not self.advanced:IsShown())
end

SD.ControlHelpers = {text=text, slider=slider, button=button, check=check}
