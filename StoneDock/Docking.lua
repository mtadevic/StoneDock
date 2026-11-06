local _, SD = ...

-- Frame coordinates are expressed in each frame's effective scale. Normalize
-- them before comparing Blizzard controls with the design canvas.
local function rootRect(frame)
    if not frame or not frame.GetRect then return end
    local x, y, w, h = frame:GetRect()
    if not x or not y or not w or not h then return end
    local factor = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * factor, y * factor, w * factor, h * factor
end

local function union(frames)
    local left, bottom, right, top
    for _, frame in ipairs(frames) do
        if frame and frame:IsShown() then
            local x, y, w, h = rootRect(frame)
            if x and w > 0 and h > 0 then
                left = left and math.min(left, x) or x
                bottom = bottom and math.min(bottom, y) or y
                right = right and math.max(right, x + w) or x + w
                top = top and math.max(top, y + h) or y + h
            end
        end
    end
    if left then return (left + right) / 2, (bottom + top) / 2, right-left, top-bottom end
end

local function bagButtons()
    local frames = {}
    if MainMenuBarBagManager and MainMenuBarBagManager.EnumerateBagButtons then
        for _, button in MainMenuBarBagManager:EnumerateBagButtons() do table.insert(frames, button) end
    elseif MainMenuBarBackpackButton then
        table.insert(frames, MainMenuBarBackpackButton)
    end
    if BagBarExpandToggle then table.insert(frames, BagBarExpandToggle) end
    return frames
end

-- Forever's native tracking bars start at 1192 units, and their Edit Mode
-- slider cannot shrink them far enough for a dashboard well. Resize the
-- existing native containers and their native contents; never replace XP data.
function SD:FitTrackingBars()
    if self.trackingFitBusy or InCombatLockdown() then return end
    local _,_,_,interface=GetBuildInfo()
    if interface~=16001 then return end
    if self.editing or (EditModeManagerFrame and EditModeManagerFrame:IsShown()) then return end
    local active=self.db and self.db.enabled and self.db.arrangeUtility and self:IsOurLayoutActive()
    local g=active and self:GetGeometry()
    self.trackingWidths=self.trackingWidths or {}
    self.trackingFitBusy=true
    local ok,err=pcall(function()
        for i,frame in ipairs({MainStatusTrackingBarContainer,SecondaryStatusTrackingBarContainer}) do
            local previous=self.trackingWidths[frame]
            local width
            if active then
                local well=i==1 and g.leftWell or g.rightWell
                local factor=frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
                width=(well.w-26)*g.scale/factor
                if not previous then previous={original=frame:GetWidth()}self.trackingWidths[frame]=previous end
                previous.fitted=width
            elseif previous then
                if math.abs(frame:GetWidth()-previous.fitted)<0.25 then width=previous.original end
                self.trackingWidths[frame]=nil
            end
            if width and math.abs(frame:GetWidth()-width)>0.25 then
                frame:SetWidth(width)
                if frame.ResizeContainerBars then frame:ResizeContainerBars() end
                if frame.UpdateDividers and frame.GetExpectedSegments then frame:UpdateDividers(frame:GetExpectedSegments()) end
            end
            if width and frame.BarFrameTexture and math.abs(frame.BarFrameTexture:GetWidth()-width)>0.25 then
                frame.BarFrameTexture:SetWidth(width)
            end
        end
    end)
    self.trackingFitBusy=nil
    if not ok then self:ReportError("Fit tracking bars",err) end
end

function SD:PrecisionAlign(bagsOnly)
    if InCombatLockdown() or self.editing or not self:IsOurLayoutActive() then return end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end
    local full = self:GetFullLayouts()
    if not full then return end
    local index = full.activeLayout
    local layout = full.layouts[index]
    local g = self:GetGeometry()
    local changed = false
    local function correct(system, systemIndex, frames, targetX, targetY)
        local x, y = union(frames)
        if not x then return end
        local dx, dy = targetX - x, targetY - y
        if math.abs(dx) < 0.25 and math.abs(dy) < 0.25 then return end
        for _, info in ipairs(layout.systems) do
            if info.system == system and (systemIndex == nil or info.systemIndex == systemIndex) then
                info.anchorInfo.offsetX = info.anchorInfo.offsetX + dx
                info.anchorInfo.offsetY = info.anchorInfo.offsetY + dy
                changed = true
                break
            end
        end
    end
    if not bagsOnly then
        local nativeBars = { MainActionBar, MultiBarBottomLeft, MultiBarBottomRight, MultiBarRight }
        for n, spec in ipairs(g.bars) do
            local bar, buttons = nativeBars[n], {}
            if bar and bar.actionButtons then
                for i = 1, 12 do
                    if bar.actionButtons[i] then table.insert(buttons, bar.actionButtons[i]) end
                end
            elseif bar then table.insert(buttons, bar) end
            correct(Enum.EditModeSystem.ActionBar, spec.index, buttons, spec.x * g.scale, spec.y * g.scale)
        end
        -- Native auxiliary frames have invisible padding; align visible icons.
        for _,spec in ipairs({
            {11,StanceBar,g.leftWell,true,MultiBarBottomLeft,g.bars[2]},
            {12,PetActionBar,g.rightWell,false,MultiBarRight,g.bars[4]},
            {13,PossessActionBar,g.rightWell,false,MultiBarRight,g.bars[4]},
        }) do
            local frame,well=spec[2],spec[3]
            local buttons={}
            if frame and frame.actionButtons then
                for _,button in ipairs(frame.actionButtons) do buttons[#buttons+1]=button end
            elseif frame then buttons[1]=frame end
            local _,_,w,h=union(buttons)
            if w then
                local edge=(spec[4] and well.x+well.w-12 or well.x+12)*g.scale
                local bottom=(well.y+well.h-18*g.density)*g.scale
                local main=spec[5]
                local _,_,mainWidth,mainHeight=union(main and (main.actionButtons or {main}) or {})
                if mainWidth then
                    edge=spec[6].x*g.scale+(spec[4] and mainWidth/2 or -mainWidth/2)
                    bottom=spec[6].y*g.scale+mainHeight/2+4*g.scale
                end
                local targetX=edge+(spec[4] and -w/2 or w/2)
                correct(Enum.EditModeSystem.ActionBar,spec[1],buttons,targetX,bottom+h/2)
            end
        end
        correct(Enum.EditModeSystem.Minimap, nil, { Minimap },
            (g.map.x + g.map.w / 2) * g.scale, (g.map.y + g.map.h / 2) * g.scale)
        if self.db.arrangeUtility then
            correct(Enum.EditModeSystem.MicroMenu, nil, { MicroMenu },
                (g.menuDrawer.x + g.menuDrawer.w / 2) * g.scale,
                (g.menuDrawer.y + g.menuDrawer.h / 2 + 2) * g.scale)
        end
    end
    if self.db.arrangeUtility then
        correct(Enum.EditModeSystem.Bags, nil, bagButtons(),
            (g.bagDrawer.x + g.bagDrawer.w / 2) * g.scale,
            (g.bagDrawer.y + g.bagDrawer.h / 2 + 1) * g.scale)
    end
    if changed then self:SaveAndRefreshLayout(full, index) end
end

function SD:SchedulePrecisionAlignment(bagsOnly)
    if self.precisionBusy then return end
    if self.precisionPending then
        if not bagsOnly then self.precisionBagsOnly = false end
        return
    end
    self.precisionPending, self.precisionBagsOnly = true, bagsOnly == true
    C_Timer.After(0.35, function()
        local onlyBags = SD.precisionBagsOnly
        SD.precisionPending = nil
        if InCombatLockdown() then
            SD.precisionAfterCombat = SD.precisionAfterCombat ~= false and onlyBags
            return
        end
        SD.precisionBusy = true
        SD:Run("Fit dashboard controls", function() SD:PrecisionAlign(onlyBags) end)
        SD.precisionBusy = nil
    end)
end

function SD:DockBags()
    if self.reflowingBags or InCombatLockdown() or self.editing then return end
    if not self.db.enabled or not self.db.arrangeUtility or not self:IsOurLayoutActive() then return end
    local manager = ContainerFrameSettingsManager
    if not manager or not manager.GetBagsShown then return end
    local bags = manager:GetBagsShown()
    if not bags or #bags == 0 then return end
    local g = self:GetGeometry()
    local baseline = (g.right.y + g.right.h + 12) * g.scale
    local available = UIParent:GetHeight() - baseline - 16
    local tallest = 1
    for _, frame in ipairs(bags) do tallest = math.max(tallest, frame:GetHeight()) end
    local scale = math.min(1, bags[1]:GetScale(), available / tallest)
    scale = math.max(0.35, math.floor(scale * 100) / 100)
    self.reflowingBags=true
    local inset, y, columnWidth = 12, baseline, 0
    local previousCombined = false
    local ok,err=pcall(function()
    for n, frame in ipairs(bags) do
        local height, width = frame:GetHeight() * scale, frame:GetWidth() * scale
        if n > 1 and (previousCombined or y + height > UIParent:GetHeight() - 12) then
            inset = inset + columnWidth + 12
            columnWidth, y = 0, baseline
        end
        frame:SetScale(scale)
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -inset / scale, y / scale)
        y = y + height + 6
        columnWidth = math.max(columnWidth, width)
        previousCombined = frame.IsCombinedBagContainer and frame:IsCombinedBagContainer() or false
    end
    end)
    self.reflowingBags=nil
    if not ok then error(err)end
    self.bagsDocked = true
end

function SD:RefreshDocking()
    if InCombatLockdown() then return end
    self:FitTrackingBars()
    local active = self.db.enabled and self.db.arrangeUtility and self:IsOurLayoutActive() and not self.editing
    if active then self:DockBags()
    elseif self.bagsDocked and UpdateContainerFrameAnchors then
        self.bagsDocked = nil
        self.reflowingBags = true
        local ok, err = pcall(UpdateContainerFrameAnchors)
        self.reflowingBags = nil
        if not ok then self:ReportError("Restore bag placement", err) end
    end
end

function SD:CreateDocking()
    if not hooksecurefunc then return end
    if not self.trackingFitHooked and StatusTrackingBarManager then
        self.trackingFitHooked=true
        for _,method in ipairs({"CheckForLayoutChange","UpdateBarVisuals"}) do
            if type(StatusTrackingBarManager[method])=="function" then
                hooksecurefunc(StatusTrackingBarManager,method,function() SD:FitTrackingBars() end)
            end
        end
    end
    if not self.bagWindowHooked and UpdateContainerFrameAnchors then
        self.bagWindowHooked = true
        hooksecurefunc("UpdateContainerFrameAnchors", function()
            if SD.db then SD:Run("Bag window placement", function() SD:DockBags() end) end
        end)
    end
    if not self.bagControlsHooked and BagsBar and BagsBar.Layout then
        self.bagControlsHooked = true
        hooksecurefunc(BagsBar, "Layout", function()
            if SD.db and SD.db.enabled and SD:IsOurLayoutActive() and not SD.precisionBusy then
                SD:SchedulePrecisionAlignment(true)
            end
        end)
    end
end

SD:On("ADDON_LOADED", function()
    if SD.db then SD:CreateDocking() end
end)
SD:On("PLAYER_REGEN_ENABLED", function()
    SD:RefreshDocking()
    local onlyBags = SD.precisionAfterCombat
    if onlyBags ~= nil then
        SD.precisionAfterCombat = nil
        SD:SchedulePrecisionAlignment(onlyBags)
    end
end)
-- Blizzard persists the native layout. Check visible controls after login so
-- delayed native sizing does not leave them offset; never rebuild the layout.
function SD:CheckLoginAlignment()
    if self.layoutWriteBusy or self.loginAlignmentBusy or not self.loginAlignmentPending or not self.db then return false end
    if InCombatLockdown() or self.editing then return false end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return false end
    if not self.db.enabled or not self:IsOurLayoutActive() then return false end
    -- Claim this pass before SaveLayouts dispatches layout-update callbacks.
    self.loginAlignmentPending=nil
    if StoneDockCharDB and (StoneDockCharDB.auxiliaryPlacement~="edge-bars-6" or self:NeedsGeometryAlignment()) then
        self.loginAlignmentBusy=true
        local ok=self:Run("Position auxiliary bars",function()
            if self:AlignLayout() then StoneDockCharDB.auxiliaryPlacement="edge-bars-6" end
        end)
        self.loginAlignmentBusy=nil
        return ok
    end
    self:SchedulePrecisionAlignment()
    return true
end
SD:On("PLAYER_ENTERING_WORLD",function()
    if SD.loginAlignmentStarted then return end
    SD.loginAlignmentStarted=true
    SD.loginAlignmentPending=true
    C_Timer.After(2,function() SD:CheckLoginAlignment() end)
    -- One settling pass for native frames whose final dimensions load late.
    C_Timer.After(5,function()
        if SD.db and SD.db.enabled and SD:IsOurLayoutActive() then
            SD.loginAlignmentPending=true
            SD:CheckLoginAlignment()
        end
    end)
end)
SD:On("PLAYER_REGEN_ENABLED",function() SD:CheckLoginAlignment() end)
SD:On("EDIT_MODE_LAYOUTS_UPDATED",function() SD:CheckLoginAlignment() end)

local resizeQueued
local function queueResizeAlignment()
    if resizeQueued then return end
    resizeQueued = true
    C_Timer.After(0.4,function()
        resizeQueued = nil
        if not SD.db or not SD:NeedsGeometryAlignment() then return end
        SD.loginAlignmentPending = true
        SD:CheckLoginAlignment()
    end)
end
SD:On("DISPLAY_SIZE_CHANGED",queueResizeAlignment)
SD:On("UI_SCALE_CHANGED",queueResizeAlignment)
