local _, SD = ...

-- Blizzard animates tracking container alpha as bars appear and change.
-- A cached alpha can be zero even when the XP bar should be visible later.
local names = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
    "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar", "PossessActionBar",
    "BuffFrame", "DebuffFrame", "StoneDockUtilityRoot", "MinimapCluster", "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "PartyFrame", "CompactPartyFrame",
    "CompactRaidFrameContainer", "ChatFrame1", "GeneralDockManager",
    "MicroMenuContainer", "BagsBar" }

function SD:CollectFadeFrames()
    self.fadeFrames = self.fadeFrames or {}
    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame and frame.GetAlpha and (not frame.IsForbidden or not frame:IsForbidden()) and self.fadeFrames[frame] == nil then
            self.fadeFrames[frame] = true
        end
    end
end

local function hasManagedAncestor(frame, frames)
    if not frame.GetParent then return false end
    local parent = frame:GetParent()
    for _ = 1, 12 do
        if not parent or parent == UIParent then return false end
        if frames[parent] ~= nil then return true end
        parent = parent.GetParent and parent:GetParent()
    end
    return false
end

function SD:SetFadeAlphas(ui, hud)
    if self.canvas then self.canvas:SetAlpha(self.db.opacity * ui) end
    if self.gulveigBacking then self.gulveigBacking:SetAlpha(ui) end
    if self.hud then self.hud:SetAlpha(hud) end
    self.fadeOriginalAlphas = self.fadeOriginalAlphas or {}
    for frame in pairs(self.fadeFrames or {}) do
        local base = self.fadeOriginalAlphas[frame]
        if ui == 1 then
            if base ~= nil then
                frame:SetAlpha(base)
                self.fadeOriginalAlphas[frame] = nil
            end
        elseif not hasManagedAncestor(frame, self.fadeFrames) then
            if base == nil then
                local alpha = frame:GetAlpha()
                if not issecretvalue or not issecretvalue(alpha) then
                    base = alpha
                    self.fadeOriginalAlphas[frame] = base
                end
            end
            if base ~= nil then frame:SetAlpha(base * ui) end
        end
    end
    self.currentUIAlpha, self.currentHUDAlpha = ui, hud
end

function SD:IsDashboardHovered()
    if not MouseIsOver then return false end
    for _, frame in pairs(self.panels or {}) do
        if frame:IsShown() and MouseIsOver(frame) then return true end
    end
    for frame in pairs(self.fadeFrames or {}) do
        if frame:IsShown() and MouseIsOver(frame) then return true end
    end
    return false
end

function SD:RefreshFading(immediate)
    if not self.db then return end
    self:SyncFadeTicker()
    if not self.fadeFrames or self.fadeFramesDirty then self:CollectFadeFrames() self.fadeFramesDirty=nil end
    if not self.fadeAnimator then self.fadeAnimator = CreateFrame("Frame") end
    if self.fadeLayoutActive==nil then self.fadeLayoutActive=self:IsOurLayoutActive()end
    local active = self.db.enabled and self.fadeLayoutActive and not self.editing
    local combat = InCombatLockdown()
    local hovered = active and self.db.fadeUI and not combat and self.db.revealOnHover and self:IsDashboardHovered()
    local ui = active and not combat and not hovered and self.db.fadeUI and self.db.uiRestAlpha or 1
    local hud = active and not combat and self.db.fadeHUD and self.db.hudRestAlpha or 1
    if self.settingsWindow and self.settingsWindow:IsShown() then ui,hud=1,1 end
    if self.options and self.options:IsShown() then ui, hud = 1, 1 end
    if self.advanced and self.advanced:IsShown() then ui, hud = 1, 1 end
    if (self.positionWindow and self.positionWindow:IsShown()) or (self.profileWindow and self.profileWindow:IsShown()) then ui,hud=1,1 end
    if self.unitOptions and self.unitOptions:IsShown() then ui, hud = 1, 1 end
    if (self.itemFlyout and self.itemFlyout:IsShown()) or (self.itemPicker and self.itemPicker:IsShown()) or (self.rivetMenu and self.rivetMenu:IsShown()) or (self.hearthMenu and self.hearthMenu:IsShown()) then ui,hud=1,1 end
    if immediate or combat then
        self.fadeAnimator:SetScript("OnUpdate", nil)
        if immediate or self.currentUIAlpha~=ui or self.currentHUDAlpha~=hud then self:SetFadeAlphas(ui, hud)end
        self.fadeTargetUI, self.fadeTargetHUD = ui, hud
        return
    end
    if self.fadeTargetUI == ui and self.fadeTargetHUD == hud then return end
    self.fadeTargetUI, self.fadeTargetHUD = ui, hud
    local fromUI, fromHUD, elapsed = self.currentUIAlpha or 1, self.currentHUDAlpha or 1, 0
    self.fadeAnimator:SetScript("OnUpdate", function(frame, delta)
        elapsed = elapsed + delta
        local t = math.min(1, elapsed / 0.25)
        SD:SetFadeAlphas(fromUI + (ui - fromUI) * t, fromHUD + (hud - fromHUD) * t)
        if t >= 1 then frame:SetScript("OnUpdate", nil) end
    end)
end

function SD:SyncFadeTicker()
    local needed=self.db and self.db.enabled and self.fadeLayoutActive~=false and not self.editing and (self.db.fadeUI or self.db.fadeHUD) and not InCombatLockdown()
    if not needed and self.fadeTicker then self.fadeTicker:Cancel()self.fadeTicker=nil end
    if needed and not self.fadeTicker then
        self.fadeTicker=C_Timer.NewTicker(.15,function()SD:Run("Visibility fade",function()SD:RefreshFading()end)end)
    end
end
function SD:CreateFading()self:RefreshFading(true)end

SD:On("PLAYER_REGEN_DISABLED", function() SD:RefreshFading(true) end)
SD:On("PLAYER_REGEN_ENABLED", function() SD:RefreshFading() end)

SD:On("EDIT_MODE_LAYOUTS_UPDATED",function()SD.fadeLayoutActive=nil end)
SD:On("ADDON_LOADED",function()SD.fadeFramesDirty=true end)
