local _, SD = ...
local function check(key, label, help) return {key=key,label=label,kind="check",help=help} end
local function selectOption(key, label, choices) return {key=key,label=label,kind="select",choices=choices} end
local function range(key, label, low, high, step)
    return {key=key,label=label,kind="range",low=low,high=high,step=step}
end
local function section(title, controls) return {title=title,controls=controls} end
local schemas = {
    appearance = {title="Theme & layout", description="Choose the look and spacing of your dashboard.", sections={
        section("Appearance",{
            selectOption("layoutVariant","Layout",{{"stone","StoneDock dashboard"},{"gulveig","Gulveig Bar"},{"tofu","Tofu Bar"}}),
            selectOption("stoneTexture","Theme",{{"weathered","Weathered Stone"},{"classic","Original Stone"},{"carved","Carved Ruins"},{"kintsugi","Onyx Kintsugi"}}),
            selectOption("accent","Accent color",{{"silver","Silver"},{"violet","Violet"},{"green","Moss"},{"bronze","Bronze"}}),
            selectOption("density","Panel height",{{0.85,"Compact"},{1,"Standard"},{1.15,"Roomy"}}),
            range("opacity","Panel opacity",0.4,1,0.05),
        }),
        section("Panel details",{check("chatStyle","Style Gulveig chat with artwork and background"),check("showLabels","Show panel headings"),check("showGuides","Show placement guides")}),
        section("Native layout management",{
            check("arrangeUnits","Arrange player, target and focus"),check("arrangeGroups","Arrange party and raid"),
            check("arrangeChat","Arrange chat"),check("arrangeUtility","Arrange bags, menu and tracking bars"),
            check("tofuShowBagBar","Show native bag bar in Tofu Bar"),
            check("useExtraBars","Enable the four dashboard action bars"),
        }),
    }},
    bars = {title="Action bars & fading",description="Move the action banks together and choose their out-of-combat visibility.",sections={
        section("Action banks",{range("barOffsetX","Horizontal offset",-100,100,1),range("barOffsetY","Vertical offset",-15,180,1),
            range("barSpread","Distance from center",-100,100,1),range("barWidth","Width (%)",70,110,1)}),
        section("Tofu item bar",{range("tofuItemOffsetX","Horizontal offset",-500,500,1),
            range("tofuItemOffsetY","Vertical offset",-180,350,1)}),
        section("Out of combat",{check("fadeUI","Fade the dashboard"),range("uiRestAlpha","Dashboard opacity",0,1,0.05),
            check("fadeHUD","Fade the curved HUD"),range("hudRestAlpha","HUD opacity",0,1,0.05),check("revealOnHover","Reveal the dashboard on mouseover")}),
    }},
    hud = {title="Curved health HUD",description="Adjust the health and resource arcs around your character.",sections={
        section("Display",{check("showHUD","Enable curved HUD"),check("hudPowerColor","Use native resource color"),
            check("hudLabels","Show health and resource labels"),check("hudTicks","Show quarter markers"),
            selectOption("hudHealthColor","Health color",{{"red","Red"},{"class","Class color"}})}),
        section("Shape & position",{range("hudGap","Distance from character",60,500,2),range("hudHeight","Arc height",140,280,2),
            range("hudArcWidth","Arc width",32,72,2),range("hudScale","Overall scale",0.6,1.4,0.05),
            range("hudOffsetX","Horizontal offset",-600,600,2),range("hudOffsetY","Vertical offset",-450,450,2)}),
    }},
    units = {title="Player, party & raid",description="Keep group frames readable and seated above your action bars.",sections={
        section("Display",{check("stoneUnits","Show stone trim"),check("groupClassColors","Use class colors"),
            check("splitRaid","Split raid groups around the map"),check("attachPlayerAuras","Attach buffs and debuffs to the player frame")}),
        section("Frame sizing",{range("unitSize","Player / target / focus size (%)",100,200,5),
            range("groupRowWidth","Group row width (%)",70,100,1),range("groupHeight","Preferred row height",24,72,2),
            range("groupOffsetX","Group horizontal offset",-350,700,5),range("groupOffsetY","Group vertical offset",-100,500,5)}),
    }},
    positioning = {title="Move & resize",description="Adjust bank and pet placement. Use Blizzard Edit Mode for individual native frames.",sections={
        section("Action banks",{range("barOffsetX","Horizontal offset",-100,100,1),range("barOffsetY","Vertical offset",-15,180,1),
            range("barWidth","Width (%)",70,110,1),range("barSpread","Distance from center",-100,100,1)}),
        section("Pet frame",{check("dockPet","Dock pet beside player"),range("petScale","Size (%)",50,150,5),
            range("petOffsetX","Horizontal offset",-500,500,2),range("petOffsetY","Vertical offset",-300,300,2)}),
    }},
}
local function read(d)
    if d.read then return d.read() end
    return SD.db[d.key]
end
local function write(d, value)
    if d.write then d.write(value) else SD.db[d.key]=value end
end
function SD:GetPreferenceDraft(key)
    self.preferenceDrafts = self.preferenceDrafts or {}
    local draft=self.preferenceDrafts[key]
    if draft and draft.profile ~= self.profileKey then self.preferenceDrafts[key]=nil end
    self.preferenceDrafts[key] = self.preferenceDrafts[key] or {values={},fields={},profile=self.profileKey}
    return self.preferenceDrafts[key]
end
function SD:PreferenceValue(page, field)
    local draft = self:GetPreferenceDraft(page)
    local pending = draft.values[field.key]
    if pending ~= nil then return pending end
    return read(field)
end
function SD:SetPreferenceValue(page, field, value)
    local draft = self:GetPreferenceDraft(page)
    draft.fields[field.key] = field
    if value == read(field) then draft.values[field.key]=nil else draft.values[field.key]=value end
    if field.key=="stoneTexture" and value=="kintsugi" then
        self:SetPreferenceValue(page,{key="accent"},"bronze")
    end
    self:RefreshSettingsFooter()
end
function SD:HasPreferenceChanges(key)
    local draft = self.preferenceDrafts and self.preferenceDrafts[key]
    return draft and next(draft.values) ~= nil or false
end
function SD:DiscardPreferences(key)
    if self.preferenceDrafts then self.preferenceDrafts[key]=nil end
    self:OpenSettingsTab(key)
end
function SD:ApplyPreferences(key)
    local busy, why = self:IsBusy()
    if busy then SD.Print(why) return false end
    local draft = self.preferenceDrafts and self.preferenceDrafts[key]
    if not draft or not next(draft.values) then return true end
    if draft.profile ~= self.profileKey then
        self.preferenceDrafts[key]=nil
        SD.Print("Your specialization changed. Review this page for the current profile.")
        self:OpenSettingsTab(key)
        return false
    end
    if key=="gathering" then
        local binding = draft.values.gatheringKey
        if binding and binding ~= "" and GetBindingAction then
            local action = GetBindingAction(binding)
            if action ~= "" and action ~= "INTERACTTARGET" then
                SD.Print("That key already has a WoW action. Choose another fishing key.")
                return false
            end
        end
    end
    local previous = self:GetGeometry()
    local nativeBackup
    if self:IsOurLayoutActive() then nativeBackup=self:GetFullLayouts() end
    local itemBackup=key=="items" and {rules=SD.Copy(self.db.itemRules),pins=SD.Copy(self.db.itemOverrides),hearth=self.db.preferredHearth}
    local originals = {}
    local changed = {}
    for id, value in pairs(draft.values) do
        local field = draft.fields[id]
        originals[id] = {value=read(field)}
        changed[id] = true
        write(field, value)
    end
    local oldLayoutName=self.layoutName
    local ok, failure = pcall(function()
        if changed.layoutVariant and not self:ActivateLayoutVariant(self.db.layoutVariant) then error("Could not activate the selected layout.") end
        if self:IsOurLayoutActive() then
            local layoutChanges = changed.density or changed.barOffsetX or changed.barOffsetY or changed.barWidth or changed.barSpread
            if layoutChanges and not self:AlignLayout(self.db.nativeGeometry or previous) then error("Could not save layout placement.") end
            if (changed.unitSize or changed.groupHeight or changed.groupRowWidth or changed.groupOffsetX or changed.groupOffsetY or changed.arrangeGroups) and not self:ApplyUnitLayout() then error("Could not save unit frame settings.") end
            if key=="positioning" and self.db.dockPet and not self:ApplyPetLayout() then error("Could not save pet placement.") end
            if key=="appearance" and changed.useExtraBars then self:ApplyBarVisibility() end
        end
        for _, entry in ipairs(self.moduleDefinitions) do
            if changed[entry.key] or changed["module:"..entry.key] then
                local value = self.db[entry.key]
                if entry.flag then value = self:IsModuleEnabled(entry.key) end
                if not self:SetModule(entry.key,value) then error("Could not apply "..entry.label) end
            end
        end
        if changed.dockPet and not self.db.dockPet then self:DetachPetFrame() end
        if changed.attachPlayerAuras then
            if self.db.attachPlayerAuras then self:ApplySessionLayout(true) else self:RestoreOriginalAuras() end
        end
        if key=="gathering" then
            if changed.gatheringKey then self:StopGathering() end
            if not self.db.gatheringEnabled then self:StopGathering() else self:UpdatePoleFishing() end
        end
        if key=="items" then
            for spec, pins in pairs(self.db.itemOverrides) do
                for category, id in pairs(pins) do
                    local rules=(self.db.itemRules[spec] or {})[category]
                    if rules and rules[id]==false then pins[category]=nil end
                end
            end
            local spec=self.itemSpec or self:GetConsumableSpec()
            local rules=(self.db.itemRules[spec] or {}).hearth
            if rules and rules[self.db.preferredHearth]==false then self.db.preferredHearth=nil end
            self:ScanConsumables() self:ScanHearthstones()
        end
        self:RefreshPanels()
        self:RefreshHUD()
        self:RefreshFading()
        self:RefreshUnitTrim()
        self:RefreshUtilityButtons(true)
    end)
    if not ok then
        self.layoutName=oldLayoutName
        for id, old in pairs(originals) do write(draft.fields[id],old.value) end
        if itemBackup then self.db.itemRules=itemBackup.rules self.db.itemOverrides=itemBackup.pins self.db.preferredHearth=itemBackup.hearth end
        if nativeBackup then
            local restored=pcall(self.SaveAndRefreshLayout,self,nativeBackup,nativeBackup.activeLayout)
            if not restored then SD.Print("Native layout recovery failed. Use Profiles & backups to restore your layout.") end
        end
        self:RefreshPanels()
        SD.Print(tostring(failure).." Your pending choices are still available.")
        return false
    end
    self.preferenceDrafts[key] = nil
    self:OpenSettingsTab(key)
    return true
end

function SD:SettingsDropdown(parent, label, choices, value, choose, create)
    local dropdown = create("DropdownButton",nil,parent,"WowStyle1DropdownTemplate")
    dropdown:SetSize(300,30)
    local function caption()
        for _, choice in ipairs(choices) do if choice[1]==value() then return choice[2] end end
        local current=value()
        return current~=nil and tostring(current) or label
    end
    local function update()
        if dropdown.SetDefaultText then dropdown:SetDefaultText(caption()) end
    end
    update()
    if dropdown.SetupMenu then
        dropdown:SetupMenu(function(_,root)
            if root.SetScrollMode then root:SetScrollMode(320) end
            for _, choice in ipairs(choices) do
                root:CreateRadio(choice[2],function() return value()==choice[1] end,function()
                    choose(choice[1])
                    update()
                end)
            end
        end)
    end
    return dropdown
end

function SD:BuildPreferencePage(key, definition)
    local create,H = self:WindowBuilder("preferences:"..key)
    local page=create("Frame",nil,self.settingsWindow.content)
    page.controls={}
    H.text(page,definition.title,24,22,-20,630)
    H.text(page,definition.description,12,22,-60,630)
    local y=definition.top or -110
    for _, group in ipairs(definition.sections) do
        local height=47+#group.controls*51
        local card=create("Frame",nil,page,"BackdropTemplate")
        card:SetPoint("TOPLEFT",14,y)
        card:SetSize(648,height)
        self:StyleCard(card,false)
        H.text(card,group.title,15,16,-14,600):SetTextColor(SD:CardAccent())
        for i,field in ipairs(group.controls) do
            local top=-42-(i-1)*51
            local control
            if field.kind=="check" then
                control=create("CheckButton",nil,card,"UICheckButtonTemplate")
                control:SetPoint("TOPLEFT",14,top)
                control:SetSize(26,26)
                control:SetChecked(self:PreferenceValue(key,field)==true)
                H.text(control,field.label,13,32,-6,550)
                control:SetScript("OnClick",function(button) SD:SetPreferenceValue(key,field,button:GetChecked()==true) end)
            elseif field.kind=="select" then
                H.text(card,field.label,12,18,top-7,250)
                control=self:SettingsDropdown(card,field.label,field.choices,
                    function() return SD:PreferenceValue(key,field) end,
                    function(value) SD:SetPreferenceValue(key,field,value) if field.rebuild then SD:OpenSettingsTab(key) end end,create)
                control:SetPoint("TOPLEFT",320,top)
            elseif field.kind=="range" then
                local valueLabel=H.text(card,field.label,12,18,top-6,280)
                control=create("Slider",nil,card)
                control:SetPoint("TOPLEFT",324,top-6)
                control:SetSize(285,16)
                control:SetOrientation("HORIZONTAL")
                control:SetMinMaxValues(field.low,field.high)
                control:SetValueStep(field.step)
                control:SetObeyStepOnDrag(true)
                control:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
                local track=control.track or control:CreateTexture(nil,"BACKGROUND")
                control.track=track
                track:SetAllPoints()
                track:SetColorTexture(.17,.22,.26,1)
                local function show(value)
                    valueLabel:SetText(field.label.."  "..string.format(field.step<1 and "%.2f" or "%d",value))
                end
                control:SetScript("OnValueChanged",nil)
                local value=self:PreferenceValue(key,field) or field.low
                control:SetValue(value)
                show(value)
                control:SetScript("OnValueChanged",function(_,newValue)
                    newValue=field.low+math.floor((newValue-field.low)/field.step+0.5)*field.step
                    show(newValue)
                    SD:SetPreferenceValue(key,field,newValue)
                end)
            end
            if field.help then
                control:SetScript("OnEnter",function()
                    GameTooltip:SetOwner(control,"ANCHOR_RIGHT") GameTooltip:SetText(field.label)
                    GameTooltip:AddLine(field.help,.75,.8,.85,true) GameTooltip:Show()
                end)
                control:SetScript("OnLeave",function() GameTooltip:Hide() end)
            end
            page.controls[field.key]=control
        end
        y=y-height-16
    end
    if key=="appearance" then
        H.text(page,"Layout tools",15,22,y-8,600)
        H.button(page,"Create / activate layout",22,y-40,295,function()
            if SD:HasPreferenceChanges(key) then SD.Print("Apply this page before activating a layout.") return end
            SD:ActivateLayout()
        end)
        H.button(page,"Restore previous layout",335,y-40,295,function() if SD:HasPreferenceChanges(key) then SD.Print("Apply or revert this page first.") return end SD:RestoreLayout() end)
        H.button(page,"Blizzard Edit Mode",22,y-80,295,function() SD:OpenEditMode() end)
        H.button(page,"Rebuild managed placement",335,y-80,295,function()
            if SD:HasPreferenceChanges(key) then SD.Print("Apply this page before rebuilding.") return end
            SD:ConfirmRebuild()
        end)
        y=y-130
    elseif key=="positioning" then
        H.button(page,"Blizzard Edit Mode",22,y-8,295,function() SD:OpenEditMode() end)
        y=y-60
    elseif key=="units" then
        local choices={{0,"Close preview"},{5,"Party (5)"},{10,"Raid (10)"},{20,"Raid (20)"},{25,"Raid (25)"},{40,"Raid (40)"}}
        H.text(page,"Frame preview",15,22,y-8,280)
        local preview=self:SettingsDropdown(page,"Choose preview",choices,
            function() return SD.raidPreview and SD.raidPreview.count or 0 end,
            function(count) SD:PreviewRaid(count) end,create)
        preview:SetPoint("TOPLEFT",320,y-2)
        y=y-60
    end
    page:SetSize(690,math.max(400,-y+10))
    page.preferenceKey=key
    return page
end

function SD:PreferenceSchema(key)
    if schemas[key] then return schemas[key] end
    if key=="master" then
        local groups={}
        local definitions={}
        for _, entry in ipairs(self.moduleDefinitions) do definitions[entry.key]=entry end
        for _, group in ipairs({
            {"Dashboard",{"enabled","showInfo","showUtility","arrangeUtility","rivets","positioning","notesCustomize"}},
            {"Combat & frames",{"showHUD","fadeUI","fadeHUD","stoneUnits","arrangeGroups","splitRaid","dockPet","attachPlayerAuras"}},
            {"Gameplay & profiles",{"gatheringEnabled","session","readiness","waypoints","quests","profiles"}},
        }) do
            local controls={}
            for _, id in ipairs(group[2]) do
                local entry=definitions[id]
                local field=check(entry.flag and "module:"..entry.key or entry.key,entry.label,entry.description)
                if entry.flag then
                    field.read=function() return SD:IsModuleEnabled(entry.key) end
                    field.write=function(value) SD.db.moduleFlags[entry.key]=value end
                end
                controls[#controls+1]=field
            end
            groups[#groups+1]=section(group[1],controls)
        end
        return {title="Enable features",description="Choose the StoneDock features you want, then apply this page.",sections=groups}
    end
    if key=="notesCustomize" then
        local groups={}
        for _, entry in ipairs(self.noteRowDefinitions) do
            local row=check("row:"..entry[1],"Show "..entry[2])
            row.read=function() return SD.db.noteRows[entry[1]]~=false end
            row.write=function(value) SD.db.noteRows[entry[1]]=value end
            local action=selectOption("action:"..entry[1],"Click action",self.noteActionDefinitions)
            action.read=function() return SD.db.noteActions[entry[1]] or "default" end
            action.write=function(value) SD.db.noteActions[entry[1]]=value end
            groups[#groups+1]=section(entry[2],{row,action})
        end
        return {title="Command Center",description="Choose visible rows and their shortcuts. An expedition card appears here while gathering.",sections=groups}
    end
    if key=="rivets" then
        local controls={}
        for _, panel in ipairs({{"left","Conversation"},{"right","Command Center"},{"map","Map"},{"leftWell","Left action bank"},{"rightWell","Right action bank"}}) do
            for index=1,2 do
                local id=panel[1]..index
                local field=selectOption(id,panel[2]..(index==1 and " / left" or " / right"),self.rivetActionOptions)
                field.read=function() return SD.db.rivetActions[id] or SD.rivetActionDefaults[panel[1]][index] end
                field.write=function(value) SD.db.rivetActions[id]=value end
                controls[#controls+1]=field
            end
        end
        return {title="Corner shortcuts",description="Choose an action for each corner rivet.",sections={section("Rivet actions",controls)}}
    end
end

function SD:BuildItemPreferences(category)
    self:ScanConsumables()
    self:ScanHearthstones()
    local categories={}
    for _, item in ipairs(self.itemCategories) do categories[#categories+1]={item.key,item.label} end
    categories[#categories+1]={"hearth","Hearthstones"}
    categories[#categories+1]={"trinkets","Trinkets"}
    self.settingsItemKey=category or self.settingsItemKey or "bufffood"
    local key=self.settingsItemKey
    local spec=self.itemSpec or self:GetConsumableSpec()
    local items=key=="hearth" and (self.hearthstones or {}) or (self.allConsumables or {})
    if key=="trinkets" then
        items={}
        for slot=13,14 do
            local id=GetInventoryItemID("player",slot)
            if id then local name=C_Item.GetItemInfo(id) items[#items+1]={id=id,name=name or ("Item "..id)} end
        end
    end
    local controls={}
    local preferred={{0,"Automatic best available"}}
    for _, item in ipairs(items) do preferred[#preferred+1]={item.id,item.name} end
    if key~="trinkets" then
        local field=selectOption("preferred:"..spec..":"..key,"Preferred item",preferred)
        field.read=function()
            if key=="hearth" then return SD.db.preferredHearth or 0 end
            return (SD.db.itemOverrides[spec] or {})[key] or 0
        end
        field.write=function(value)
            if key=="hearth" then SD.db.preferredHearth=value~=0 and value or nil
            else
                SD.db.itemOverrides[spec]=SD.db.itemOverrides[spec] or {}
                SD.db.itemOverrides[spec][key]=value~=0 and value or nil
            end
        end
        controls[#controls+1]=field
    end
    self.settingsRuleItems=self.settingsRuleItems or {}
    local selected=self.settingsRuleItems[key]
    local available=false
    for _, item in ipairs(items) do if item.id==selected then available=true break end end
    if not available then selected=items[1] and items[1].id end
    self.settingsRuleItems[key]=selected
    for _, item in ipairs(items) do
        if item.id==selected then
        local field=selectOption("rule:"..spec..":"..key..":"..item.id,item.name,
            {{"auto","Automatic detection"},{"include","Always include"},{"exclude","Exclude from this category"}})
        field.read=function()
            local rules=SD.db.itemRules[spec] or {}
            local value=rules[key] and rules[key][item.id]
            if value==true then return "include" elseif value==false then return "exclude" end
            return "auto"
        end
        field.write=function(value)
            local rules=SD.db.itemRules
            rules[spec]=rules[spec] or {}
            rules[spec][key]=rules[spec][key] or {}
            if value=="auto" then rules[spec][key][item.id]=nil else rules[spec][key][item.id]=value=="include" end
        end
        controls[#controls+1]=field
        end
    end
    local page=self:BuildPreferencePage("items",{title="Consumables & travel",
        description="Choose a category and an item to edit. Apply saves all pending item rules for this specialization.",top=-205,
        sections={{title="Item preferences",controls=controls}}})
    self.itemPicker=page
    local create,H=self:WindowBuilder("itemCategory")
    H.text(page,"Category",13,30,-113,250)
    local dropdown=self:SettingsDropdown(page,"Choose category",categories,function() return key end,
        function(value) SD:OpenSettingsTab("items",value) end,create)
    dropdown:SetPoint("TOPLEFT",334,-105)
    H.text(page,"Item to configure",13,30,-158,250)
    local itemChoices={}
    for _, item in ipairs(items) do itemChoices[#itemChoices+1]={item.id,item.name} end
    if #itemChoices==0 then itemChoices={{0,"No items available"}} end
    local selector=self:SettingsDropdown(page,"Choose an item",itemChoices,function() return selected or 0 end,
        function(value) SD.settingsRuleItems[key]=value SD:OpenSettingsTab("items",key) end,create)
    selector:SetPoint("TOPLEFT",334,-150)
    return page
end
