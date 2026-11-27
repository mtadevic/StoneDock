local _, SD = ...
-- Retain the existing Adept Edit Mode identity and per-spec anchor namespace.
function SD:GetLayoutVariant() return "adept" end
function SD:InitializeLayoutVariant()
    self.layoutName="Adept"
    self.db.layoutVariant=nil
    if self.db.variantGeometries then
        self.db.nativeGeometry=SD.Copy(self.db.variantGeometries.Adept or self.db.nativeGeometry)
        self.db.variantGeometries=nil
    end
    if self.db.nativeGeometry and self.db.nativeGeometry.variant~="adept" then self.db.nativeGeometry=nil end
end
function SD:GetVariantProfileStore()
    self.profile.variantNative=self.profile.variantNative or {}
    return self.profile.variantNative,"adept"
end
function SD:ChooseFirstLayout()
    if self:IsBusy() then return false end
    self:ActivateLayout()
    if not self:IsOurLayoutActive() then return false end
    StoneDockCharDB.welcomed=true self.welcomePending=nil
    if self.layoutChooser then self.layoutChooser:Hide() end
    return true
end
function SD:PromptForLayout()
    if StoneDockCharDB.welcomed then return end
    if self:IsBusy() then self.welcomePending=true return end
    self.welcomePending=nil
    if not self.layoutChooser then
        local create,H=self:WindowBuilder("layoutChooser")
        local f=create("Frame","StoneDockLayoutChooser",UIParent,"BackdropTemplate")
        self.layoutChooser=f
        f:SetSize(520,220) f:SetPoint("CENTER") f:SetFrameStrata("DIALOG")
        f:SetClampedToScreen(true) self:StyleCard(f,false)
        H.text(f,"Welcome to Lazai Adept",23,24,-24,472)
        H.text(f,"A compact dock built around Blizzard's native controls. Your current Edit Mode layout remains available.",14,24,-72,472)
        H.button(f,"Activate Adept",24,-164,224,function()SD:ChooseFirstLayout()end)
        H.button(f,"Later",272,-164,224,function()f:Hide()end)
        UISpecialFrames[#UISpecialFrames+1]="StoneDockLayoutChooser"
    end
    self.layoutChooser:Show()
end
SD:On("PLAYER_REGEN_ENABLED",function()if SD.welcomePending then SD:PromptForLayout() end end)

function SD:RefreshVariantControls()

    if InCombatLockdown() or self.variantControlsBusy then return end

    self.variantControlsBusy=true

    local active=self.db.enabled and not self.editing and self:IsOurLayoutActive()
    local hideBags=active and not self.db.adeptShowBagBar

    self.variantHiddenControls=self.variantHiddenControls or {}

    self.variantControlHooks=self.variantControlHooks or {}

    for control,frame in pairs({menu=MicroMenuContainer or MicroMenu,bags=BagsBar,xp=MainStatusTrackingBarContainer}) do
        local hide=(control=="bags" and hideBags) or (control=="xp" and active)

        if not self.variantControlHooks[frame] and frame.HookScript then

            frame:HookScript("OnShow",function()SD:RefreshVariantControls()end)

            self.variantControlHooks[frame]=true

        end

        if hide then

            if self.variantHiddenControls[frame]==nil then self.variantHiddenControls[frame]=frame:IsShown() end

            if frame:IsShown() then frame:Hide() end

        elseif self.variantHiddenControls[frame]~=nil then

            local shown=self.variantHiddenControls[frame]

            self.variantHiddenControls[frame]=nil

            if shown then frame:Show() end

        end

    end

    self.variantControlsBusy=nil

end

