local _, SD = ...
local function safe(v)return not issecretvalue or not issecretvalue(v)end
local function now()return (time and time())or(GetTime and GetTime())or 0 end
local function num(fn,...)
    local value=fn and fn(...)
    return type(value)=="number"and safe(value)and value or 0
end
local function money(value)return string.format("%sg %ss %sc",math.floor(math.abs(value)/10000),math.floor(math.abs(value)/100)%100,math.abs(value)%100)end
local function blocked()if InCombatLockdown()then SD.Print("Use this control after combat.")return true end end
function SD:ResetSession()
    if not self:IsModuleEnabled("session")then return end
    self.session={started=now(),earned=0,spent=0,xp=0,quests=0,moneyLast=num(GetMoney),xpLast=num(UnitXP,"player"),xpMax=num(UnitXPMax,"player"),level=num(UnitLevel,"player")}
    StoneDockCharDB.sessionStats=self.session
end
function SD:RecordSessionMoney()
    if not self:IsModuleEnabled("session")then return end
    if not self.session then self:ResetSession()end
    local current=num(GetMoney)local delta=current-self.session.moneyLast
    if delta>=0 then self.session.earned=self.session.earned+delta else self.session.spent=self.session.spent-delta end
    self.session.moneyLast=current
    self:QueueFeatureRefresh("session")
end
function SD:RecordSessionXP()
    if not self:IsModuleEnabled("session")then return end
    if not self.session then self:ResetSession()end
    local s=self.session local current=num(UnitXP,"player")local level=num(UnitLevel,"player")
    local delta=current-s.xpLast
    if level>s.level then delta=math.max(0,s.xpMax-s.xpLast)+current end
    if delta>0 then s.xp=s.xp+delta end
    s.xpLast=current s.xpMax=num(UnitXPMax,"player")s.level=level
    self:QueueFeatureRefresh("session")
end
function SD:GetSessionStats()
    if not self.session then self:ResetSession()end
    if not self.session then return end
    local s=self.session local elapsed=math.max(1,now()-s.started)
    return {elapsed=elapsed,net=s.earned-s.spent,earned=s.earned,spent=s.spent,xp=s.xp,quests=s.quests,goldPerHour=(s.earned-s.spent)/10000*3600/elapsed,xpPerHour=s.xp*3600/elapsed}
end
function SD:QueueFeatureRefresh(key)
    if not self.settingsWindow or not self.settingsWindow:IsShown()or self.settingsTab~=key then return end
    if self.featureRefreshPending then return end
    self.featureRefreshPending=true
    C_Timer.After(.3,function()
        SD:Run("Refresh notebook",function()if SD.settingsWindow:IsShown()and SD.settingsTab==key then SD:OpenSettingsTab(key)end end)
        SD.featureRefreshPending=nil
    end)
end
local function panel(key,title,description)
    local CreateFrame,H=SD:WindowBuilder(key.."Panel")
    local f=CreateFrame("Frame",nil,UIParent)SD[key.."Panel"]=f f:SetSize(690,700)
    H.text(f,title,22,22,-22,640)H.text(f,description,12,22,-62,640)
    return f,H,CreateFrame
end
function SD:BuildSessionPanel()
    local f,H=panel("session","SESSION TRACKER","Gold, XP and quests for this play session. Elapsed time includes AFK. Reloading resumes a recently saved session; Reset starts a fresh one.")
    local labels={}
    for i=1,8 do labels[i]=H.text(f,"",16,28,-130-(i-1)*48,620)end
    local function update()
        local s=SD:GetSessionStats()if not s then return end
        local lines={string.format("Elapsed: %dh %02dm",math.floor(s.elapsed/3600),math.floor(s.elapsed/60)%60),"Gold earned: "..money(s.earned),"Gold spent: "..money(s.spent),"Net: "..(s.net<0 and "-"or "+")..money(s.net),string.format("Net gold/hour: %.1f",s.goldPerHour),"XP gained: "..s.xp,string.format("XP/hour: %.0f",s.xpPerHour),"Quests completed: "..s.quests}
        for i,line in ipairs(lines)do labels[i]:SetText(line)end
    end
    f:SetScript("OnShow",function()
        if not f.ticker then f.ticker=C_Timer.NewTicker(1,function()if f:IsShown()then update()end end)end
    end)
    f:SetScript("OnHide",function()if f.ticker then f.ticker:Cancel()f.ticker=nil end end)
    H.button(f,"Reset this session",22,-550,300,function()SD:ResetSession()update()end)
    update()f:Show()if not f.ticker then f.ticker=C_Timer.NewTicker(1,update)end
    return f
end
function SD:GetReadiness()
    local rows={}
    local function add(label,ok,detail,action)rows[#rows+1]={label=label,ok=ok,detail=detail,action=action}end
    local lowest,pieces=100,0
    if GetInventoryItemDurability then for slot=1,19 do local current,max=GetInventoryItemDurability(slot)if current and max and safe(current)and safe(max)and max>0 then pieces=pieces+1 lowest=math.min(lowest,current/max*100)end end end
    add("Equipment condition",pieces==0 or lowest>=30,pieces>0 and string.format("Lowest item: %d%% durability",lowest)or "No durability information.",function()if ToggleCharacter then ToggleCharacter("PaperDollFrame")end end)
    local free=0 if C_Container and C_Container.GetContainerNumFreeSlots then for bag=0,NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 do local count,family=C_Container.GetContainerNumFreeSlots(bag)if family==0 then free=free+(count or 0)end end end
    add("Bag space",free>=8,free.." ordinary slots free",function()if ToggleAllBags then ToggleAllBags()end end)
    local trinkets=0 for slot=13,14 do if GetInventoryItemID and GetInventoryItemID("player",slot)then trinkets=trinkets+1 end end
    add("Equipped trinkets",trinkets==2,trinkets.." of 2 equipped",function()if ToggleCharacter then ToggleCharacter("PaperDollFrame")end end)
    local categories={{"heal","Healing potion"},{"bufffood","Spec buff food"},{"food","Recovery food"}}
    local _,resource if UnitPowerType then _,resource=UnitPowerType("player")end
    if resource=="MANA"then categories[#categories+1]={"resource","Mana potion"}categories[#categories+1]={"drink","Mana recovery drink"}end
    for _,category in ipairs(categories)do
        local item=self:GetChosenItem(category[1])
        add(category[2],item~=nil,item and item.name or "No suitable item in bags / selected default missing",function()SD:ShowItemPicker(category[1],category[2])end)
    end
    return rows
end
function SD:BuildReadinessPanel()
    if not InCombatLockdown()then self:ScanConsumables()end
    local f,H=panel("readiness","READINESS CHECKLIST","A preparation checklist for your own gear and supplies. Amber means something to review, not a required purchase. Click a row to inspect or configure it.")
    f.rows=self:GetReadiness()
    local pass=0
    for i,row in ipairs(f.rows)do
        if row.ok then pass=pass+1 end
        local button=H.button(f,(row.ok and "|cff7bdc93[Ready]|r "or "|cffffc56b[Review]|r ")..row.label.." - "..row.detail,22,-130-(i-1)*55,640)
        button:SetScript("OnClick",function()if not blocked()then SD:Run("Readiness action",row.action)end end)
    end
    H.text(f,string.format("%d / %d checks ready",pass,#f.rows),16,22,-105,640)
    H.button(f,"Refresh checklist",22,-625,300,function()SD:OpenSettingsTab("readiness")end)
    return f
end
function SD:GetCurrentLocation()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return end
    local map=C_Map.GetBestMapForUnit("player")if not map then return end
    local position=C_Map.GetPlayerMapPosition(map,"player")if not position then return end
    local x,y=position:GetXY()if not safe(x)or not safe(y)then return end
    local info=C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    return {map=map,x=x*100,y=y*100,name=info and info.name or GetZoneText()or "Location"}
end
function SD:SetWaypoint(map,x,y)
    if not self:IsModuleEnabled("waypoints")or blocked()then return false end
    map,x,y=tonumber(map),tonumber(x),tonumber(y)
    if not map or map<1 or map~=math.floor(map)or not x or not y or x<0 or x>100 or y<0 or y>100 then SD.Print("Use a valid map ID and coordinates from 0 to 100.")return false end
    if not C_Map or not C_Map.SetUserWaypoint then SD.Print("This client does not provide native user waypoints.")return false end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(map)then SD.Print("Waypoints are unavailable on this map.")return false end
    local point
    if UiMapPoint and UiMapPoint.CreateFromCoordinates then point=UiMapPoint.CreateFromCoordinates(map,x/100,y/100)
    elseif CreateVector2D then point={uiMapID=map,position=CreateVector2D(x/100,y/100)}end
    if not point then SD.Print("The native map-point helper is unavailable.")return false end
    if C_Map.SetUserWaypoint(point)==false then SD.Print("The map did not accept that waypoint.")return false end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true)end
    self.lastWaypoint={map=map,x=x,y=y}
    return true
end
function SD:SaveWaypoint(name,location)
    if not self:IsModuleEnabled("waypoints")or not location then return false end
    name=(name or ""):match("^%s*(.-)%s*$"):sub(1,40)if name==""then SD.Print("Give this location a name.")return false end
    StoneDockCharDB.waypoints=StoneDockCharDB.waypoints or {}
    local points=StoneDockCharDB.waypoints local count=0 for _ in pairs(points)do count=count+1 end
    if count>=12 and not points[name]then SD.Print("12 locations saved. Reuse a name to update its location.")return false end
    points[name]=SD.Copy(location)return true
end
function SD:BuildWaypointsPanel()
    local f,H,CreateFrame=panel("waypoints","WAYPOINT DESK","Set a native navigation pin, bookmark your current location, or copy coordinates. Nothing travels automatically; navigation uses Blizzard's own map and guidance.")
    local current=self:GetCurrentLocation()
    H.text(f,current and string.format("Here: %s | %.1f, %.1f | map %d",current.name,current.x,current.y,current.map)or "Coordinates are unavailable in this area.",13,22,-115,640)
    local function edit(text,x,y,width)
        local field=CreateFrame("EditBox",nil,f,"InputBoxTemplate")field:SetSize(width,28)field:SetPoint("TOPLEFT",x,y)field:SetAutoFocus(false)field:SetMaxLetters(40)field:SetText(text)return field
    end
    H.text(f,"Map ID",12,25,-160,180)H.text(f,"X (0-100)",12,245,-160,180)H.text(f,"Y (0-100)",12,465,-160,180)
    f.mapEdit=edit(current and tostring(current.map)or "",28,-185,190)
    f.xEdit=edit(current and string.format("%.1f",current.x)or "",248,-185,190)
    f.yEdit=edit(current and string.format("%.1f",current.y)or "",468,-185,190)
    H.button(f,"Set navigation pin",22,-230,300,function()SD:SetWaypoint(f.mapEdit:GetText(),f.xEdit:GetText(),f.yEdit:GetText())end)
    H.button(f,"Clear navigation pin",350,-230,300,function()if not blocked()and C_Map and C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint()end end)
    f.nameEdit=edit("My location",28,-295,285)
    H.button(f,"Bookmark current location",350,-293,300,function()if SD:SaveWaypoint(f.nameEdit:GetText(),SD:GetCurrentLocation())then SD:OpenSettingsTab("waypoints")end end)
    H.button(f,"Copy current coordinates",22,-345,628,function()
        local location=SD:GetCurrentLocation()
        if location then SD:ShowCopyDialog("Location coordinates",string.format("%s | %.1f, %.1f | map %d",location.name,location.x,location.y,location.map))else SD.Print("No coordinates available here.")end
    end)
    local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")scroll:SetPoint("TOPLEFT",22,-400)scroll:SetSize(630,230)
    local child=CreateFrame("Frame",nil,scroll)scroll:SetScrollChild(child)
    local names={}for name in pairs(StoneDockCharDB.waypoints or {})do names[#names+1]=name end table.sort(names)
    child:SetSize(600,math.max(230,#names*38))
    for i,name in ipairs(names)do local location=StoneDockCharDB.waypoints[name]
        H.button(child,string.format("%s | %.1f, %.1f",name,location.x,location.y),0,-(i-1)*38,595,function()SD:SetWaypoint(location.map,location.x,location.y)end)
    end
    return f
end
function SD:GetNotebookQuests()
    local quests={}local api=C_QuestLog
    if not api or not api.GetNumQuestWatches or not api.GetQuestIDForQuestWatchIndex then return quests end
    for i=1,math.min(50,api.GetNumQuestWatches())do
        local id=api.GetQuestIDForQuestWatchIndex(i)
        if id and safe(id)then
            local title=api.GetTitleForQuestID and api.GetTitleForQuestID(id)
            local done=api.IsComplete and api.IsComplete(id)
            local objectives=api.GetQuestObjectives and api.GetQuestObjectives(id)or {}
            quests[#quests+1]={id=id,title=title or ("Quest "..id),done=done,objectives=objectives}
        end
    end
    return quests
end
function SD:BuildQuestsPanel()
    local f,H,CreateFrame=panel("quests","QUEST NOTEBOOK","Your tracked quests and objectives, collected in one place. Open a quest in Blizzard's map/journal without changing your tracking list.")
    local quests=self:GetNotebookQuests()
    H.text(f,#quests.." tracked quests",14,22,-112,640)
    local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")scroll:SetPoint("TOPLEFT",22,-150)scroll:SetSize(630,480)
    local child=CreateFrame("Frame",nil,scroll)scroll:SetScrollChild(child)
    local y=0
    for _,quest in ipairs(quests)do
        local b=H.button(child,(quest.done and "|cff7bdc93[Complete]|r "or "")..quest.title,0,-y,605,function()
            if blocked()then return end
            if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(quest.id)
            elseif C_QuestLog.SetSelectedQuest then C_QuestLog.SetSelectedQuest(quest.id)if ToggleQuestLog then ToggleQuestLog()end end
        end)
        b:SetScript("OnEnter",function()GameTooltip:SetOwner(b,"ANCHOR_LEFT")GameTooltip:SetText(quest.title)GameTooltip:AddLine("Click to open the native quest details.",.75,.8,.85,true)GameTooltip:Show()end)
        b:SetScript("OnLeave",function()GameTooltip:Hide()end)
        y=y+38
        for i,objective in ipairs(quest.objectives)do if i>10 then break end
            H.text(child,(objective.finished and "|cff7bdc93"or "|cffc5cbd0")..(objective.text or "Objective").."|r",12,12,-y,585)y=y+34
        end
        y=y+14
    end
    if #quests==0 then H.text(child,"Track quests in Blizzard's quest log to see them here.",13,0,0,590)end
    child:SetSize(610,math.max(480,y))
    return f
end
SD:On("PLAYER_LOGIN",function()
    if SD:IsModuleEnabled("session")then
        local saved=StoneDockCharDB.sessionStats
        if saved and saved.exited and now()-saved.exited<180 then SD.session=saved SD.session.moneyLast=num(GetMoney)SD.session.xpLast=num(UnitXP,"player")SD.session.xpMax=num(UnitXPMax,"player")SD.session.level=num(UnitLevel,"player")else SD:ResetSession()end
    end
end)
SD:On("PLAYER_LOGOUT",function()if SD.session then SD.session.exited=now()end end)
SD:On("PLAYER_MONEY",function()SD:RecordSessionMoney()end)
SD:On("PLAYER_XP_UPDATE",function(unit)if unit=="player"then SD:RecordSessionXP()end end)
SD:On("QUEST_TURNED_IN",function()if SD:IsModuleEnabled("session")then if not SD.session then SD:ResetSession()end SD.session.quests=SD.session.quests+1 end SD:QueueFeatureRefresh("quests")end)
SD:On("QUEST_LOG_UPDATE",function()SD:QueueFeatureRefresh("quests")end)
SD:On("QUEST_WATCH_LIST_CHANGED",function()SD:QueueFeatureRefresh("quests")end)
SD:On("BAG_UPDATE_DELAYED",function()SD:QueueFeatureRefresh("readiness")end)
SD:On("PLAYER_EQUIPMENT_CHANGED",function()SD:QueueFeatureRefresh("readiness")end)
SD:On("UPDATE_INVENTORY_DURABILITY",function()SD:QueueFeatureRefresh("readiness")end)
