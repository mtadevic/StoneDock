local _, SD = ...
local builders={
    appearance=SD.ToggleOptions,
    bars=SD.ToggleAdvanced,
    units=SD.ToggleUnitOptions,
    items=SD.ShowItemPicker,
    profiles=SD.ShowProfiles,
    positioning=SD.ShowPositioning,
    rivets=SD.ShowRivetAssignments,
}
local tabs={
    {"master","Enable features","masterPanel","Getting started"},
    {"profiles","Profiles & backups","profileWindow"},
    {"appearance","Theme & layout","options","Interface"},
    {"positioning","Move & resize","positionWindow"},
    {"bars","Action bars & fading","advanced"},
    {"hud","Curved health HUD","hudPanel"},
    {"units","Player, party & raid","unitOptions"},
    {"rivets","Corner shortcuts","rivetMenu"},
    {"notesCustomize","Field Notes","notesCustomizePanel"},
    {"items","Consumables & travel","itemPicker","Gameplay"},
    {"gathering","Gathering & fishing","gatheringPanel"},
    {"readiness","Readiness checklist","readinessPanel"},
    {"session","Session tracker","sessionPanel"},
    {"waypoints","Saved waypoints","waypointsPanel"},
    {"quests","Tracked quests","questsPanel"},
}
function SD:CloseSettings()
    if self.settingsWindow then self.settingsWindow:Hide()end
end
function SD:CreateSettingsWindow()
    if self.settingsWindow then return end
    local f=CreateFrame("Frame","StoneDockSettings",UIParent,"BackdropTemplate")self.settingsWindow=f
    f:SetSize(950,820)f:SetScale(math.min(1,(UIParent:GetWidth()-40)/950,(UIParent:GetHeight()-40)/820))f:SetPoint("CENTER")f:SetFrameStrata("DIALOG")f:SetClampedToScreen(true)
    f:SetMovable(true)f:EnableMouse(true)f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function()f:StartMoving()end)f:SetScript("OnDragStop",function()f:StopMovingOrSizing()end)
    f:SetBackdrop({bgFile="Interface\\AddOns\\StoneDock\\Media\\WeatheredStone.tga",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=256,edgeSize=16})
    f:SetBackdropColor(.5,.5,.5,1)
    local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")title:SetPoint("TOPLEFT",22,-20)title:SetText("STONEDOCK  |  SETTINGS")
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton")close:SetPoint("TOPRIGHT",-6,-6)close:SetScript("OnClick",function()SD:CloseSettings()end)
    local line=f:CreateTexture(nil,"BORDER")line:SetColorTexture(.4,.45,.48,.35)line:SetPoint("TOPLEFT",198,-54)line:SetSize(1,740)
    f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")f.scroll:SetPoint("TOPLEFT",210,-54)f.scroll:SetSize(704,736)
    f.content=CreateFrame("Frame",nil,f.scroll)f.content:SetSize(690,780)f.scroll:SetScrollChild(f.content)
    f.tabs={}
    local y = -60
    for _,spec in ipairs(tabs)do
        if spec[4] then
            local heading = f:CreateFontString(nil,"OVERLAY","GameFontNormal")
            heading:SetPoint("TOPLEFT",22,y)
            heading:SetText(spec[4])
            y = y - 23
        end
        local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
        b:SetSize(170,30)b:SetPoint("TOPLEFT",18,y)b:SetText(spec[2])
        y = y - 35
        b:SetScript("OnClick",function()SD:OpenSettingsTab(spec[1])end)
        b.selected=b:CreateTexture(nil,"OVERLAY")b.selected:SetColorTexture(.55,.65,.7,.2)b.selected:SetAllPoints()b.selected:Hide()
        f.tabs[spec[1]]=b
    end
    local note=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")note:SetPoint("BOTTOMLEFT",22,25)note:SetWidth(165)note:SetJustifyH("LEFT")note:SetText("Changes save as you go.\nUse Profiles & backups to save a snapshot.")
    f:SetScript("OnHide",function()
        for _,spec in ipairs(tabs)do local page=SD[spec[3]]if page then page:Hide()end end
        if SD.rivetSettingsPage then SD.rivetSettingsPage:Hide()end
        if SD.disabledModulePage then SD.disabledModulePage:Hide()end
        SD:ClearPositionHandles()SD:RefreshFading()
    end)
    table.insert(UISpecialFrames,"StoneDockSettings")
    f:Hide()
end
function SD:AdoptSettingsPage(page,parent,y)
    if not page then return end
    page:SetParent(parent or self.settingsWindow.content)page:ClearAllPoints()page:SetPoint("TOPLEFT",0,y or 0)
    page:SetScale(1)page:SetFrameStrata("DIALOG")page:SetFrameLevel(self.settingsWindow:GetFrameLevel()+3)
    if page.SetBackdrop then page:SetBackdrop(nil)end
    page:SetMovable(false)page:SetClampedToScreen(false)
    page:SetScript("OnDragStart",nil)page:SetScript("OnDragStop",nil)
    if page.closeButton then page.closeButton:Hide()end
    for i=#UISpecialFrames,1,-1 do
        local name=UISpecialFrames[i]
        if name=="StoneDockOptions"or name=="StoneDockAdvanced"then table.remove(UISpecialFrames,i)end
    end
    page:Show()
end
function SD:BuildRivetSettings(key,anchor)
    if not self.rivetSettingsPage then
        local f=CreateFrame("Frame",nil,self.settingsWindow.content)self.rivetSettingsPage=f
        f:SetSize(690,700)
        local H=self.ControlHelpers
        H.text(f,"RIVET ACTIONS",20,20,-20,640)
        H.text(f,"Select a corner rivet, then assign its action below.",12,20,-56,640)
        local panels={{"left","Conversation"},{"right","Field Notes"},{"map","Map"},{"leftWell","Left action bank"},{"rightWell","Right action bank"}}
        for row,spec in ipairs(panels)do for i=1,2 do
            local id=spec[1]..i
            H.button(f,spec[2]..(i==1 and " - left"or " - right"),20+(i-1)*315,-80-(row-1)*34,300,function()SD:OpenSettingsTab("rivets",id,SD.rivetControls and SD.rivetControls[id])end)
        end end
    end
    key=key or self.settingsRivetKey or "left1"self.settingsRivetKey=key
    anchor=anchor or (self.rivetControls and self.rivetControls[key])or UIParent
    builders.rivets(self,key,anchor)
    self:AdoptSettingsPage(self.rivetMenu,self.rivetSettingsPage,-270)
    return self.rivetSettingsPage
end
function SD:OpenSettingsTab(key,arg,label)
    if self.settingsBuilding then return end
    key=key or self.settingsTab or "master"
    if (key=="items"or key=="positioning")and InCombatLockdown()then SD.Print("Configure items and positioning after combat.")return end
    if key=="positioning"and(self:IsBusy()or not self:IsOurLayoutActive())then SD.Print("Activate StoneDock and close Blizzard Edit Mode before positioning.")return end
    self:CreateSettingsWindow()
    self.settingsBuilding=true
    local ok,err=pcall(function()
        for _,spec in ipairs(tabs)do local page=self[spec[3]]if page then page:Hide()end end
        if self.rivetSettingsPage then self.rivetSettingsPage:Hide()end
        if self.disabledModulePage then self.disabledModulePage:Hide()end
        local page
        local featureKeys={session=true,readiness=true,waypoints=true,quests=true,notesCustomize=true,positioning=true,rivets=true,profiles=true}
        if featureKeys[key]and not self:IsModuleEnabled(key)then
            local CreateFrame,H=self:WindowBuilder("disabledModulePage")
            page=CreateFrame("Frame",nil,self.settingsWindow.content)self.disabledModulePage=page page:SetSize(690,450)
            H.text(page,"MODULE DISABLED",22,22,-22,640)
            H.text(page,"Enable this feature in Master Modules to configure and use it.",13,22,-70,640)
            H.button(page,"Open Master Modules",22,-120,350,function()SD:OpenSettingsTab("master")end)
        elseif key=="master"then page=self:BuildMasterPanel()
        elseif key=="gathering"then page=self:BuildGatheringPanel()
        elseif key=="hud"then page=self:BuildHUDPanel()
        elseif key=="session"then page=self:BuildSessionPanel()
        elseif key=="readiness"then page=self:BuildReadinessPanel()
        elseif key=="waypoints"then page=self:BuildWaypointsPanel()
        elseif key=="quests"then page=self:BuildQuestsPanel()
        elseif key=="notesCustomize"then page=self:BuildNotesPanel()
        elseif key=="rivets"then page=self:BuildRivetSettings(arg,label)
        elseif key=="items"then
            self.settingsItemKey=arg or self.settingsItemKey or "bufffood"
            local caption=label
            if not caption then for _,category in ipairs(self.itemCategories)do if category.key==self.settingsItemKey then caption=category.label end end end
            builders.items(self,self.settingsItemKey,caption or self.settingsItemKey)page=self.itemPicker
        elseif key=="appearance"then builders.appearance(self,true)page=self.options
        elseif key=="bars"then builders.bars(self,true)page=self.advanced
        elseif key=="units"then builders.units(self)page=self.unitOptions
        elseif key=="profiles"then builders.profiles(self)page=self.profileWindow
        elseif key=="positioning"then builders.positioning(self)page=self.positionWindow
        end
        if not page then error("Unknown settings tab: "..tostring(key))end
        self:AdoptSettingsPage(page)
        self.settingsWindow.content:SetSize(690,page:GetHeight())
        if self.settingsWindow.scroll.SetVerticalScroll then self.settingsWindow.scroll:SetVerticalScroll(0)end
        self.settingsPage=page
        self.settingsTab=key
        for id,button in pairs(self.settingsWindow.tabs)do button.selected:SetShown(id==key)end
        self.settingsWindow:Show()self:RefreshFading(true)
    end)
    self.settingsBuilding=nil
    if not ok then error(err)end
end
function SD:ToggleOptions(force)
    if force~=true and self.settingsWindow and self.settingsWindow:IsShown()then self:CloseSettings()return end
    self:OpenSettingsTab("master")
end
function SD:ToggleAdvanced()self:OpenSettingsTab("bars")end
function SD:ToggleUnitOptions()self:OpenSettingsTab("units")end
function SD:ShowItemPicker(key,label)self:OpenSettingsTab("items",key,label)end
function SD:ShowProfiles()self:OpenSettingsTab("profiles")end
function SD:ShowPositioning()self:OpenSettingsTab("positioning")end
function SD:ShowRivetAssignments(key,anchor)self:OpenSettingsTab("rivets",key,anchor)end
SD:On("PLAYER_REGEN_DISABLED",function()if SD.settingsTab=="positioning"then SD:CloseSettings()end end)
