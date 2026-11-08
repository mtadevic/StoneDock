local _, SD = ...
SD.moduleDefinitions={
 {key="enabled",label="Dashboard & stone panels",description="Master visibility for the dock, Command Center, item row and optional HUD."},
 {key="showInfo",label="Command Center",description="Clickable status information on the right panel."},
 {key="showHUD",label="Curved health/resource HUD",description="The optional curved player display."},
 {key="showUtility",label="Trinkets & consumable row",description="Secure item buttons and their flyouts."},
 {key="stoneUnits",label="Unit-frame stone trim",description="Decorative edges on native group frames."},
 {key="arrangeGroups",label="Group-frame arrangement",description="Automatically seat party/raid cells in the grooves."},
 {key="splitRaid",label="Split raid banks",description="Distribute raid groups across the map."},
 {key="dockPet",label="Pet-frame docking",description="Keep the pet frame attached beside the player."},
 {key="attachPlayerAuras",label="Player aura arrangement",description="Attach native buffs above and debuffs below the player."},
 {key="arrangeUtility",label="Bag/menu docking",description="Automatically arrange bag windows and interface controls."},
 {key="fadeUI",label="Dashboard combat fading",description="Use your configured out-of-combat opacity."},
 {key="fadeHUD",label="HUD combat fading",description="Separate fading for the curved HUD."},
 {key="rivets",flag=true,label="Clickable rivets",description="Corner buttons and assigned actions."},
 {key="profiles",flag=true,label="Profiles & layout snapshots",description="Automatic spec settings and named recovery snapshots."},
 {key="positioning",flag=true,label="Positioning editor",description="Draggable handles and sizing controls."},
 {key="session",flag=true,label="Session tracker",description="Gold, XP and play-session statistics."},
 {key="readiness",flag=true,label="Readiness checklist",description="Gear, bags and consumable preparation."},
 {key="waypoints",flag=true,label="Waypoint desk",description="Coordinates, saved locations and native navigation."},
 {key="quests",flag=true,label="Quest notebook",description="Tracked quests, objectives and map shortcuts."},
 {key="gatheringEnabled",label="Gathering & fishing",description="Track catches and materials in Command Center."},
 {key="notesCustomize",flag=true,label="Command Center customization",description="Choose visible information and click actions."},
}
function SD:IsModuleEnabled(key)
    return self.db and (not self.db.moduleFlags or self.db.moduleFlags[key]~=false)
end
function SD:SetModule(key,enabled)
    if InCombatLockdown() then SD.Print("Change modules after combat.")return false end
    local definition
    for _,entry in ipairs(self.moduleDefinitions)do if entry.key==key then definition=entry break end end
    if not definition then return false end
    if definition.flag then self.db.moduleFlags[key]=enabled else self.db[key]=enabled end
    if key=="profiles"and enabled then self:ActivateCharacterProfile()end
    if key=="session"and enabled then self:ResetSession()end
    if key=="dockPet"then if enabled then self:ApplyPetLayout()else self:DetachPetFrame()end end
    if key=="attachPlayerAuras"then if enabled then self:ApplySessionLayout(true)else self:RestoreOriginalAuras()end end
    if key=="arrangeUtility"and enabled then self:AlignLayout()end
    if (key=="gatheringEnabled" or key=="enabled") and not enabled then self:StopGathering() end
    if key=="gatheringEnabled" and enabled then self:UpdatePoleFishing() end
    self:RefreshPanels()
    self:RefreshRivetVisibility()
    if not self:IsModuleEnabled("positioning")then self:ClearPositionHandles()end
    if key=="arrangeGroups"or key=="splitRaid"then
        if CompactRaidFrameContainer and CompactRaidFrameContainer.TryUpdate then CompactRaidFrameContainer:TryUpdate()end
        if CompactPartyFrame and CompactPartyFrame.UpdateLayout then CompactPartyFrame:UpdateLayout()end
        self:QueueRaidSplit()
    end
    return true
end
function SD:RefreshRivetVisibility()
    for _,button in pairs(self.rivetControls or {})do button:SetShown(self:IsModuleEnabled("rivets"))end
end
function SD:BuildMasterPanel()
    local CreateFrame,H=self:WindowBuilder("masterPanel")
    local f=CreateFrame("Frame",nil,UIParent)self.masterPanel=f f:SetSize(690,720)
    H.text(f,"Enable features",22,22,-20,640)
    H.text(f,"Choose which StoneDock features to use. Open a category on the left to configure it. Changes apply outside combat.",12,22,-62,640)
    f.checks={}
    local groups = {
        {"Dashboard", {"enabled", "showInfo", "showUtility", "arrangeUtility", "rivets", "positioning", "notesCustomize"}},
        {"Combat & group frames", {"showHUD", "fadeUI", "fadeHUD", "stoneUnits", "arrangeGroups", "splitRaid", "dockPet", "attachPlayerAuras"}},
        {"Gameplay tools & profiles", {"gatheringEnabled", "session", "readiness", "waypoints", "quests", "profiles"}},
    }
    local definitions = {}
    for _, entry in ipairs(self.moduleDefinitions) do definitions[entry.key] = entry end
    local top = -110
    for _, group in ipairs(groups) do
        local heading = H.text(f, group[1], 14, 22, top, 640)
        heading:SetTextColor(1, .82, .45)
        top = top - 27
        for i, key in ipairs(group[2]) do
            local entry = definitions[key]
            local x = 22 + ((i-1)%2)*330
            local y = top - math.floor((i-1)/2)*33
            local b=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")b:SetSize(25,25)b:SetPoint("TOPLEFT",x,y)
            H.text(b,entry.label,12,29,-5,282)
            local value=entry.flag and self:IsModuleEnabled(entry.key)or self.db[entry.key]
            if entry.flag then value=self:IsModuleEnabled(entry.key)end
            b:SetChecked(not not value)
            b:SetScript("OnClick",function(button)
                SD:Run("Set module",function()if not SD:SetModule(entry.key,button:GetChecked()==true)then
                    local actual=entry.flag and SD:IsModuleEnabled(entry.key)or SD.db[entry.key]
                    if entry.flag then actual=SD:IsModuleEnabled(entry.key)end
                    button:SetChecked(not not actual)
                end end)
            end)
            b:SetScript("OnEnter",function()GameTooltip:SetOwner(b,"ANCHOR_RIGHT")GameTooltip:SetText(entry.label)GameTooltip:AddLine(entry.description,.75,.8,.85,true)GameTooltip:Show()end)
            b:SetScript("OnLeave",function()GameTooltip:Hide()end)
            f.checks[entry.key]=b
        end
        top = top - math.ceil(#group[2]/2)*33 - 13
    end
    H.text(f,"Snapshots preserve module choices. Appearance/docking defaults are shared; HUD, groups and pet preferences follow the current character/spec.",11,22,-675,640)
    return f
end
SD:On("PLAYER_LOGIN",function()SD:RefreshRivetVisibility()end)

function SD:RestoreOriginalAuras()
    local backup=StoneDockCharDB.preFeatureLayout
    if not backup or not self:IsOurLayoutActive()then return end
    local full=self:GetFullLayouts()if not full then return end
    local layout=full.layouts[full.activeLayout]local changed=false
    for i,info in ipairs(layout.systems)do
        if info.system==Enum.EditModeSystem.AuraFrame then
            local original=self.UnitLayoutHelpers.find(backup,info.system,info.systemIndex)
            if original and not SD.Equal(original,info)then layout.systems[i]=SD.Copy(original)changed=true end
        end
    end
    if changed then self:SaveAndRefreshLayout(full,full.activeLayout)self:CaptureProfile()end
end
function SD:DetachPetFrame()
    if not PetFrame or not PetFrame.GetRect or not self:IsOurLayoutActive()then return end
    local x,y=PetFrame:GetRect()if not x or not y then return end
    local full=self:GetFullLayouts()if not full then return end
    local info=self.UnitLayoutHelpers.find(full.layouts[full.activeLayout],Enum.EditModeSystem.UnitFrame,Enum.EditModeUnitFrameSystemIndices.Pet)
    if not info then return end
    local scale=PetFrame:GetEffectiveScale()/UIParent:GetEffectiveScale()
    self.UnitLayoutHelpers.anchor(info,"BOTTOMLEFT","BOTTOMLEFT",x*scale,y*scale)
    self:SaveAndRefreshLayout(full,full.activeLayout)self:CaptureProfile()
end
