local _, SD = ...
-- Display-only: never creates secure buttons, assigns unit attributes or changes nameplates.
local MAX_ROWS=6
local plates,order={},{}
local serial=0
local enabled=false
local ticker,queued
local panel
local preview=false
local peak=0
local samples={}
local stats={candidates=0,hostile=0,restricted=0,listed=0}
local function plain(value) return not issecretvalue or not issecretvalue(value) end
local function number(value) return type(value)=="number" and plain(value) end
local function yes(value) return plain(value) and (value==true or value==1) end
local function state(value)
    if not plain(value) then return "restricted" end
    if value==nil then return "nil" end
    if value==true then return "true" end
    if value==false then return "false" end
    if type(value)=="number" then return "number:"..tostring(value) end
    return type(value)
end
local function same(a,b)
    if not UnitIsUnit then return false end
    local ok,value=pcall(UnitIsUnit,a,b)
    return ok and yes(value)
end
local function keyFor(unit)
    -- Nameplate objects and unit tokens are public handles, not hidden identities.
    -- Prefer the same plate handle for target/focus aliases when available.
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit and
        (unit=="target" or unit=="focus" or unit:match("^nameplate%d+$")) then
        local ok,plate=pcall(C_NamePlate.GetNamePlateForUnit,unit)
        if ok and plate and plain(plate) then return plate end
    end
    local guid=UnitGUID and UnitGUID(unit)
    if plain(guid) and type(guid)=="string" then return guid end
    stats.restricted=stats.restricted+1
    if unit~="target" and same(unit,"target") then return "target" end
    return unit
end
function SD:GetAdeptEnemyStatus()
    return string.format("Enemy panel: active=%s combat=%s visible=%s; last scan candidates=%d hostile=%d restricted identities=%d listed=%d",
        tostring(not not enabled),tostring(not not InCombatLockdown()),tostring(panel and panel:IsShown() or false),
        stats.candidates,stats.hostile,stats.restricted,stats.listed)
        .."; peak listed="..peak.."; preview="..tostring(preview).."\nEnemy scan: "..table.concat(samples,"; ")
end
local function label(parent,size)
    local t=parent:CreateFontString(nil,"OVERLAY")
    t:SetFont("Fonts\\ARIALN.TTF",size,"") t:SetJustifyH("LEFT") t:SetWordWrap(false)
    return t
end
local function create()
    panel=CreateFrame("Frame","StoneDockAdeptEnemies",UIParent,"BackdropTemplate")
    SD.adeptEnemies=panel
    panel:EnableMouse(false) panel:SetFrameStrata("MEDIUM") panel:SetClampedToScreen(true)
    panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    panel:SetBackdropColor(.08,.082,.085,.94) panel:SetBackdropBorderColor(.4,.36,.27,.8)
    panel.title=label(panel,9) panel.title:SetPoint("TOPLEFT",6,-4)
    panel.title:SetTextColor(.88,.8,.61)
    panel.drag=CreateFrame("Frame",nil,panel)
    panel.drag:SetPoint("TOPLEFT") panel.drag:SetPoint("TOPRIGHT") panel.drag:SetHeight(18)
    panel.drag:EnableMouse(true) panel.drag:RegisterForDrag("LeftButton")
    panel:SetMovable(true)
    panel.drag:SetScript("OnDragStart",function()
        if InCombatLockdown() or SD.editing then return end
        panel.dragging=true panel.dragGeometry=SD:GetGeometry() panel:StartMoving()
    end)
    panel.drag:SetScript("OnDragStop",function() SD:FinishAdeptEnemyDrag() end)
    panel:SetScript("OnHide",function() SD:FinishAdeptEnemyDrag() end)
    panel.rows={}
    for i=1,MAX_ROWS do
        local row=CreateFrame("Frame",nil,panel,"BackdropTemplate")
        row:EnableMouse(false) row:SetSize(164,24) row:SetPoint("TOPLEFT",4,-(18+(i-1)*26))
        row:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        row.health=CreateFrame("StatusBar",nil,row)
        row.health:EnableMouse(false) row.health:SetPoint("BOTTOMLEFT",2,2) row.health:SetSize(160,4)
        row.health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8") row.health:SetStatusBarColor(.66,.6,.45,1)
        local track=row.health:CreateTexture(nil,"BACKGROUND") track:SetAllPoints() track:SetColorTexture(.19,.19,.18,1)
        row.name=label(row,10) row.name:SetPoint("TOPLEFT",3,-3) row.name:SetWidth(108)
        row.name:SetTextColor(.9,.88,.8)
        row.status=label(row,8) row.status:SetPoint("TOPRIGHT",-3,-4) row.status:SetWidth(46) row.status:SetJustifyH("RIGHT")
        panel.rows[i]=row
    end
    panel:Hide()
end
local function groupUnits()
    local result={"player","pet"}
    local count=GetNumGroupMembers and GetNumGroupMembers() or 0
    if not number(count) then count=0 end
    local raid=IsInRaid and yes(IsInRaid())
    for i=1,math.min(40,raid and count or math.max(0,count-1)) do
        local unit=(raid and "raid" or "party")..i
        result[#result+1]=unit result[#result+1]=(raid and "raidpet" or "partypet")..i
    end
    return result
end
local function threat(unit,enemy)
    local status=UnitThreatSituation and UnitThreatSituation(unit,enemy)
    if number(status) then return status end
end
function SD:FinishAdeptEnemyDrag()
    if not panel or not panel.dragging then return end
    panel.dragging=nil panel:StopMovingOrSizing()
    local x,y=panel:GetLeft(),panel:GetBottom()
    if not number(x) or not number(y) then return end
    local g=panel.dragGeometry or self:GetGeometry()
    panel.dragGeometry=nil
    local factor=panel:GetEffectiveScale()/UIParent:GetEffectiveScale()
    self.db.adeptEnemyOffsetX=x*factor/g.scale-1522
    self.db.adeptEnemyOffsetY=y*factor/g.scale-140*g.density
    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x*factor,y*factor)
end
function SD:EnemyPanelCommand(argument)
    if argument~="test" then SD.Print(self:GetAdeptEnemyStatus()) return end
    if InCombatLockdown() then SD.Print("Preview the enemy panel outside combat.") return end
    self:RefreshAdeptEnemies(self:GetGeometry())
    if not enabled then SD.Print("Enable the enemy panel in Adept's unit settings first.") return end
    preview=not preview
    if preview then
        panel:SetFrameStrata("MEDIUM") panel:SetHeight(98) panel.title:SetText("ENEMIES - PREVIEW")
        for i,row in ipairs(panel.rows) do
            row:SetShown(i<=3)
            if i<=3 then
                row.name:SetText(({"Current target","Attacking you","Group enemy"})[i])
                row.health:SetMinMaxValues(0,100) row.health:SetValue(100-i*18)
                row.status:SetText(i==2 and "ON YOU" or "COMBAT") row.status:SetTextColor(.9,.8,.5)
                row:SetBackdropBorderColor(i==1 and 1 or .25,i==1 and .78 or .25,i==1 and .3 or .23,1)
            end
        end
        panel:Show()
    else panel:Hide() end
end
function SD:UpdateAdeptEnemies()
    if not enabled then return end
    if panel then panel.drag:EnableMouse(not InCombatLockdown()) end
    if preview and not InCombatLockdown() then return end
    preview=false
    if not InCombatLockdown() then
        if panel then panel:Hide() end
        order={} serial=0 return
    end
    stats={candidates=0,hostile=0,restricted=0,listed=0}
    samples={}
    local plateCount=0 for _ in pairs(plates) do plateCount=plateCount+1 end
    samples[1]="tracked plates="..plateCount
    local units={"target","focus","boss1","boss2","boss3","boss4","boss5"}
    for unit in pairs(plates) do units[#units+1]=unit end
    local group=groupUnits()
    local found,seen={},{}
    for _,unit in ipairs(units) do
        local exists=UnitExists and UnitExists(unit)
        local hostile=UnitCanAttack and UnitCanAttack("player",unit)
        local dead=UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
        if yes(exists) then
            stats.candidates=stats.candidates+1
            if #samples<7 then samples[#samples+1]=unit.." exists="..state(exists).." attack="..state(hostile).." dead="..state(dead) end
        end
        if yes(exists) and yes(hostile) and not yes(dead) then
            stats.hostile=stats.hostile+1
            local guid=keyFor(unit)
            if not seen[guid] then
                local status=threat("player",unit)
                local victim=unit.."target"
                local fightingValue=UnitAffectingCombat and UnitAffectingCombat(unit)
                local fighting=yes(fightingValue)
                if #samples<10 then samples[#samples+1]=unit.." fighting="..state(fightingValue).." threat="..(status~=nil and tostring(status) or "unavailable") end
                local onYou=(fighting and same(victim,"player")) or (status and status>=2)
                local engaged=status~=nil or onYou
                if not engaged then
                    for _,member in ipairs(group) do
                        if threat(member,unit)~=nil  then engaged=true break end
                    end
                end
                local affiliation=engaged and "GROUP" or "COMBAT"
                local denied=UnitIsTapDenied and UnitIsTapDenied(unit)
                if not engaged and fighting and plain(denied) and not denied then engaged=true end
                if engaged then
                    seen[guid]=true
                    if not order[guid] then serial=serial+1 order[guid]=serial end
                    found[#found+1]={unit=unit,guid=guid,order=order[guid],status=status,onYou=onYou,affiliation=affiliation,
                        target=same(unit,"target")}
                end
            end
        end
    end
    -- Do not retain stale enemies after death or leaving all available unit references.
    for guid in pairs(order) do if not seen[guid] then order[guid]=nil end end
    table.sort(found,function(a,b)
        if a.target~=b.target then return not not a.target end
        return a.order<b.order
    end)
    if not panel then create() end
    local count=#found
    stats.listed=count
    peak=math.max(peak,count)
    panel.title:SetText("ENEMIES "..count..(count>MAX_ROWS and ("  (+"..(count-MAX_ROWS).." hidden)") or ""))
    for i,row in ipairs(panel.rows) do
        local enemy=found[i]
        row:SetShown(enemy~=nil)
        if enemy then
            row.unit=enemy.unit
            row.name:SetText(UnitName(enemy.unit))
            row.health:SetMinMaxValues(0,UnitHealthMax(enemy.unit)) row.health:SetValue(UnitHealth(enemy.unit))
            row:SetBackdropBorderColor(enemy.target and 1 or .25,enemy.target and .78 or .25,enemy.target and .3 or .23,1)
            local status=enemy.onYou and "ON YOU" or (enemy.status==1 and "RISING" or (enemy.status~=nil and "THREAT" or enemy.affiliation))
            row.status:SetText(status)
            row.status:SetTextColor(enemy.onYou and 1 or .8,enemy.onYou and .4 or .8,enemy.onYou and .32 or .7)
        else row.unit=nil end
    end
    panel:SetHeight(20+math.min(count,MAX_ROWS)*26)
    panel:SetShown(count>0)
end
local function queue()
    if not enabled or queued then return end
    queued=true
    C_Timer.After(0,function() queued=nil if enabled then SD:UpdateAdeptEnemies() end end)
end
local function combatTicker()
    if enabled and InCombatLockdown() then
        if not ticker then ticker=C_Timer.NewTicker(.5,function()SD:UpdateAdeptEnemies()end) end
    elseif ticker then ticker:Cancel() ticker=nil end
end
function SD:RefreshAdeptEnemies(g)
    local active=self.db.enabled and self.db.adeptEnemyList~=false and g.variant=="adept"
        and not self.editing and self:IsOurLayoutActive()
    if not self.adeptEnemyEvents then
        self.adeptEnemyEvents=CreateFrame("Frame")
        self.adeptEnemyEvents:SetScript("OnEvent",function(_,event,unit)
            if event=="NAME_PLATE_UNIT_ADDED" or event=="NAME_PLATE_UNIT_REMOVED" then
                if type(unit)=="string" and plain(unit) then plates[unit]=event=="NAME_PLATE_UNIT_ADDED" and true or nil end
            end
            if event=="PLAYER_REGEN_DISABLED" then peak=0 SD:FinishAdeptEnemyDrag() end
            combatTicker() queue()
        end)
    end
    if active~=enabled then
        enabled=active self.adeptEnemyEvents:UnregisterAllEvents()
        plates={} order={} serial=0
        if enabled then
            for _,event in ipairs({"NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","PLAYER_TARGET_CHANGED",
                "PLAYER_FOCUS_CHANGED","UNIT_THREAT_LIST_UPDATE","UNIT_THREAT_SITUATION_UPDATE","UNIT_HEALTH",
                "UNIT_MAXHEALTH","UNIT_TARGET","GROUP_ROSTER_UPDATE","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","PLAYER_ENTERING_WORLD"}) do
                self.adeptEnemyEvents:RegisterEvent(event)
            end
            for _,plate in ipairs(C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}) do
                local unit=plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                if type(unit)=="string" and plain(unit) then plates[unit]=true end
            end
        end
    end
    combatTicker()
    if not enabled then preview=false if panel then panel:Hide() end return end
    if not panel then create() end
    if panel.dragging then self:FinishAdeptEnemyDrag() end
    panel.drag:EnableMouse(not InCombatLockdown())
    panel:SetScale(g.scale*g.density)
    panel:SetWidth(172) panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",(1522+(self.db.adeptEnemyOffsetX or 0))*g.scale,
        (140*g.density+(self.db.adeptEnemyOffsetY or 0))*g.scale)
    self:UpdateAdeptEnemies()
end
