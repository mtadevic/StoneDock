local _, SD = ...
local localKeys={"showHUD","hudScale","hudOffsetX","hudOffsetY","hudGap","hudHeight","hudArcWidth","hudLabels","hudTicks","hudPowerColor","hudHealthColor","fadeHUD","hudRestAlpha","stoneUnits","unitSize","groupRowWidth","groupHeight","groupOffsetX","groupOffsetY","splitRaid","attachPlayerAuras","itemOverrides","itemRules","preferredHearth","dockPet","petScale","petOffsetX","petOffsetY"}
local localSet={} for _,key in ipairs(localKeys)do localSet[key]=true end
local function specKey()
    return SD.GetConsumableSpec and SD:GetConsumableSpec() or "0"
end
local function values(db,keys)
    local result={}
    for _,key in ipairs(keys)do result[key]=SD.Copy(db[key]) end
    return result
end
local function profileSystem(info)
    return info.system==Enum.EditModeSystem.UnitFrame or info.system==Enum.EditModeSystem.AuraFrame or info.system==Enum.EditModeSystem.StatusTrackingBar
end
function SD:InitializeProfiles()
    local char=StoneDockCharDB
    char.profiles=type(char.profiles)=="table" and char.profiles or {}
    char.snapshots=type(char.snapshots)=="table" and char.snapshots or {}
    self.sharedDB=StoneDockDB
    if not self.sharedDB.hudSpreadVersion then
        if self.sharedDB.hudGap==144 then self.sharedDB.hudGap=208 end
        self.sharedDB.hudSpreadVersion=1
    end
    for _,profile in pairs(char.profiles)do
        if not profile.hudSpreadVersion then
            if profile.values and profile.values.hudGap==144 then profile.values.hudGap=208 end
            profile.hudSpreadVersion=1
        end
    end
    local key=tostring(specKey())
    if not char.profiles[key] then
        char.profiles[key]={values=values(self.sharedDB,localKeys),hudSpreadVersion=1}
    end
    self.profileKey=key self.profile=char.profiles[key]
    self.profile.values=self.profile.values or {}
    local profile=self.profile
    for _,k in ipairs(localKeys)do if profile.values[k]==nil and self.defaults[k]~=nil then profile.values[k]=SD.Copy(self.defaults[k]) end end
    self.profileNeedsRestore=true
    self.db=setmetatable({}, {
        __index=function(_,k) if localSet[k] then return profile.values[k] end return SD.sharedDB[k] end,
        __newindex=function(_,k,v) if localSet[k] then profile.values[k]=v else SD.sharedDB[k]=v end end,
    })
end
function SD:CaptureProfile()
    if not self.profile or self.profileNeedsRestore or self.profileSwitching or not self:IsOurLayoutActive() then return end
    local layout=self:GetActiveLayout()
    local native={}
    for _,info in ipairs(layout and layout.systems or {})do if profileSystem(info)then native[#native+1]=SD.Copy(info) end end
    if not SD.Equal(self.profile.native,native)then self.profile.native=native end
end
function SD:ApplyProfileNative()
    if not self.profile then return true end
    if not self.profile.native or not self:IsOurLayoutActive() then self.profileNeedsRestore=nil return true end
    self:UpgradeDefaultUnitAnchors(self.profile.native)
    if self.db.arrangeGroups then
        local info=self.UnitLayoutHelpers.find({systems=self.profile.native},Enum.EditModeSystem.UnitFrame,Enum.EditModeUnitFrameSystemIndices.Party)
        self:ConfigureNativeParty(info)
    end
    local full=self:GetFullLayouts() if not full then return false end
    local layout=full.layouts[full.activeLayout]
    local changed=false
    for i,info in ipairs(layout.systems)do
        for _,saved in ipairs(self.profile.native)do
            if info.system==saved.system and info.systemIndex==saved.systemIndex then
                if not SD.Equal(info,saved)then layout.systems[i]=SD.Copy(saved)changed=true end
                break
            end
        end
    end
    if not changed then self.profileNeedsRestore=nil return true end
    self.profileSwitching=true
    local ok=self:Run("Apply character profile",function() self:SaveAndRefreshLayout(full,full.activeLayout) end)
    self.profileSwitching=nil
    if ok then self.profileNeedsRestore=nil end
    return ok
end
function SD:SwitchProfile()
    if not self.profile or tostring(specKey())==self.profileKey then return end
    if self:IsBusy() then self.profilePending=true return end
    self:CaptureProfile()
    self:InitializeProfiles()
    self.profilePending=nil
    self:ApplyProfileNative()
    self:RefreshPanels()
end
function SD:SnapshotData()
    local settings={}
    for key in pairs(self.defaults)do settings[key]=SD.Copy(self.db[key]) end
    return {settings=settings,layout=self:IsOurLayoutActive() and self:GetActiveLayout() or nil,character=UnitName and UnitName("player") or "Character",spec=self.profileKey,version=self.version,created=date("%Y-%m-%d %H:%M")}
end
function SD:SaveSnapshot(name)
    if self.IsModuleEnabled and not self:IsModuleEnabled("profiles")then SD.Print("Enable Profiles & layout snapshots in Master Modules first.")return false end
    if self:IsBusy() then SD.Print("Finish combat and close Edit Mode before saving a snapshot.") return false end
    name=(name or ""):match("^%s*(.-)%s*$"):sub(1,48)
    if name=="" then SD.Print("Enter a snapshot name.") return false end
    local snapshots=StoneDockCharDB.snapshots
    local count=0 for _ in pairs(snapshots)do count=count+1 end
    if not snapshots[name] and count>=20 then SD.Print("20 snapshots saved. Reuse an existing name to update it.") return false end
    snapshots[name]=self:SnapshotData()
    SD.Print("Saved snapshot: "..name)
    return true
end
function SD:RestoreSnapshotData(snapshot)
    if self:IsBusy() or not snapshot then return false end
    -- Only restore our active native layout; no other named layout is edited.
    if snapshot.layout and not self:IsOurLayoutActive() then SD.Print("Activate StoneDock before restoring its native layout.") return false end
    self.profileSwitching=true
    local ok=true
    if snapshot.layout then
        local full=self:GetFullLayouts()
        if not full then self.profileSwitching=nil return false end
        local layout=SD.Copy(snapshot.layout) layout.layoutName=self.layoutName
        full.layouts[full.activeLayout]=layout
        ok=self:Run("Restore layout snapshot",function() self:SaveAndRefreshLayout(full,full.activeLayout) end)
    end
    if ok then
        for key in pairs(self.defaults)do if snapshot.settings[key]~=nil then self.db[key]=SD.Copy(snapshot.settings[key]) end end
    end
    self.profileSwitching=nil
    if ok then self:RefreshPanels() self:CaptureProfile() end
    return ok
end
function SD:RestoreSnapshot(name)
    if self.IsModuleEnabled and not self:IsModuleEnabled("profiles")then SD.Print("Enable Profiles & layout snapshots in Master Modules first.")return false end
    local snapshot=StoneDockCharDB.snapshots[name]
    if not snapshot or self:IsBusy() then SD.Print("Snapshot unavailable, or combat/Edit Mode is active.") return false end
    StoneDockCharDB.snapshotUndo=self:SnapshotData()
    return self:RestoreSnapshotData(snapshot)
end
function SD:ShowProfiles()
    if not self.profile then self:InitializeProfiles() end
    if self.profileWindow then self.profileWindow:Hide() end
    local CreateFrame,H=self:WindowBuilder("profileWindow")
    local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate") self.profileWindow=f
    f:SetSize(620,710) f:SetPoint("CENTER") f:SetFrameStrata("DIALOG") f:SetClampedToScreen(true)
    self:StyleCard(f,false)
    H.text(f,"PROFILES & LAYOUT SNAPSHOTS",20,22,-22,575)
    H.text(f,"Character: "..(UnitName and UnitName("player") or "Current").."  |  Spec: "..(self.itemSpecName or self.profileKey),12,22,-60,575)
    H.text(f,"Stone artwork and action-bank geometry are shared. HUD, unit/pet placement, group sizing and item preferences are saved per character/spec. Snapshots include shared appearance and the native layout.",12,22,-88,575)
    local identity=H.card(f,"CURRENT PROFILE","Character: "..(UnitName and UnitName("player") or "Current").." | "..(self.itemSpecName or self.profileKey),22,-130,568,76,true)
    local edit=CreateFrame("EditBox",nil,f,"InputBoxTemplate") f.nameEdit=edit
    edit:SetSize(330,28) edit:SetPoint("TOPLEFT",30,-230) edit:SetAutoFocus(false) edit:SetMaxLetters(48) edit:SetText("My layout")
    H.button(f,"Save snapshot",380,-228,210,function() if SD:SaveSnapshot(edit:GetText()) then SD:ShowProfiles() end end)
    H.button(f,"Undo last restore",22,-272,275,function() SD:RestoreSnapshotData(StoneDockCharDB.snapshotUndo) end)
    H.button(f,"Export current native layout",310,-272,280,function()
        local layout=SD:GetActiveLayout()
        if layout and C_EditMode.ConvertLayoutInfoToString then SD:ShowCopyDialog("Native layout export",C_EditMode.ConvertLayoutInfoToString(layout)) end
    end)
    local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate") scroll:SetPoint("TOPLEFT",22,-320) scroll:SetSize(565,290)
    local child=CreateFrame("Frame",nil,scroll) scroll:SetScrollChild(child)
    local names={} for name in pairs(StoneDockCharDB.snapshots)do names[#names+1]=name end table.sort(names)
    child:SetSize(540,math.max(290,#names*88))
    for i,name in ipairs(names)do
        local snapshot=StoneDockCharDB.snapshots[name]
        local card=H.card(child,name,snapshot.created or "Saved layout",0,-(i-1)*88,540,76,false)
        card.title:SetWidth(370) card.detail:SetWidth(370)
        H.button(card,"Restore",394,-24,130,function() SD:RestoreSnapshot(name) end)
    end
    H.button(f,"Close settings",22,-648,568,function() SD:CloseSettings() end)
    f:Show() self:RefreshFading(true)
end
function SD:ActivateCharacterProfile()
    if self.IsModuleEnabled and not self:IsModuleEnabled("profiles")then return end
    if self.profileProcessing then return end
    if self:IsBusy() then self.profilePending=true return end
    self.profileProcessing=true
    local ok,err=pcall(function()
    if tostring(specKey())~=self.profileKey then self:SwitchProfile()
    elseif self.profileNeedsRestore then self:ApplyProfileNative() end
    self.profilePending=nil
    self:CaptureProfile()
    if not StoneDockCharDB.initialSnapshotSaved and self:IsOurLayoutActive() then
        StoneDockCharDB.snapshots["Initial layout"]=self:SnapshotData()
        StoneDockCharDB.initialSnapshotSaved=true
    end
    self:RefreshPanels()
    end)
    self.profileProcessing=nil
    if not ok then error(err)end
end
SD:On("PLAYER_LOGIN",function()
    if not SD.profile then SD:InitializeProfiles() end
    C_Timer.After(1,function() SD:Run("Activate character profile",function() SD:ActivateCharacterProfile() end) end)
end)
SD:On("PLAYER_SPECIALIZATION_CHANGED",function(unit) if not unit or unit=="player" then SD:ActivateCharacterProfile() end end)
SD:On("PLAYER_REGEN_ENABLED",function() if SD.profilePending then SD:ActivateCharacterProfile() end end)
SD:On("EDIT_MODE_LAYOUTS_UPDATED",function()
    if SD.profileSwitching or SD.profileCapturePending then return end
    SD.profileCapturePending=true
    C_Timer.After(.7,function()
        SD:Run("Capture character profile",function() if SD.profilePending then SD:ActivateCharacterProfile() else SD:CaptureProfile() end end)
        SD.profileCapturePending=nil
    end)
end)
SD:On("PLAYER_LOGOUT",function() SD:CaptureProfile() end)
