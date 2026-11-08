local _, SD = ...

function SD:ConfigurePlayerAuras(layout)
    local E,A,I=Enum.EditModeSystem,Enum.EditModeAuraFrameSetting,Enum.EditModeAuraFrameSystemIndices
    if not A or not I then return false end
    local H=self.UnitLayoutHelpers
    local g=self:GetGeometry()
    local changed=false
    for _,spec in ipairs({{I.BuffFrame,"BOTTOMLEFT","TOPLEFT",10,A.IconLimitBuffFrame,Enum.AuraFrameIconDirection.Up},
        {I.DebuffFrame,"TOPLEFT","BOTTOMLEFT",-10,A.IconLimitDebuffFrame,Enum.AuraFrameIconDirection.Down}}) do
        local info=H.find(layout,E.AuraFrame,spec[1])
        if info then
            info.anchorInfo={point=spec[2],relativeTo="PlayerFrame",relativePoint=spec[3],offsetX=0,offsetY=spec[4]*g.scale}
            info.anchorInfo2=nil info.isInDefaultPosition=false
            H.setting(info,A.Orientation,Enum.AuraFrameOrientation.Horizontal)
            H.setting(info,A.IconDirection,Enum.AuraFrameIconDirection.Right)
            H.setting(info,A.IconWrap,spec[6])
            H.setting(info,A.IconSize,60*g.scale)
            H.setting(info,A.IconPadding,5)
            H.setting(info,spec[5],6)
            changed=true
        end
    end
    return changed
end

function SD:ApplySessionLayout(force)
    if self.layoutWriteBusy or self.featureBusy or not self.db or not self.db.enabled or self:IsBusy() or not self:IsOurLayoutActive() then return false end
    if not force and StoneDockCharDB.featureLayout=="rows-auras-1" then return true end
    local full=self:GetFullLayouts()
    if not full then return false end
    local layout=full.layouts[full.activeLayout]
    local H,U,S=self.UnitLayoutHelpers,Enum.EditModeUnitFrameSystemIndices,Enum.EditModeUnitFrameSetting
    -- Keep a reviewable native backup before the first group/aura migration.
    if not StoneDockCharDB.preFeatureLayout then StoneDockCharDB.preFeatureLayout=SD.Copy(layout) end
    if self.db.arrangeGroups then
        local party=H.find(layout,Enum.EditModeSystem.UnitFrame,U.Party)
        local raid=H.find(layout,Enum.EditModeSystem.UnitFrame,U.Raid)
        H.setting(party,S.UseRaidStylePartyFrames,1)
        H.setting(party,S.UseHorizontalGroups,1)
        H.setting(raid,S.RaidGroupDisplayType,Enum.RaidGroupDisplayType.SeparateGroupsVertical)
    end
    if self.db.attachPlayerAuras then self:ConfigurePlayerAuras(layout) end
    self.featureBusy=true
    local ok=self:Run("Apply group rows and player auras",function() self:SaveAndRefreshLayout(full,full.activeLayout) end)
    if ok then
        StoneDockCharDB.featureLayout="rows-auras-1"
        self:InstallRaidSplitHook() self:QueueRaidSplit()
    end
    self.featureBusy=nil
    return ok
end
SD:On("PLAYER_ENTERING_WORLD",function() C_Timer.After(2,function() SD:Run("Initialize auras",function() SD:ApplySessionLayout() SD:QueueRaidSplit() end) end) end)
SD:On("PLAYER_REGEN_ENABLED",function() SD:ApplySessionLayout() end)
SD:On("EDIT_MODE_LAYOUTS_UPDATED",function()
    if SD.db and not SD.featurePending then
        SD.featurePending=true
        C_Timer.After(0.5,function() SD:Run("Update auras",function() SD:ApplySessionLayout() end) SD.featurePending=nil end)
    end
end)
