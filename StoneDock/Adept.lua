local _, SD = ...

function SD:GetAdeptGeometry(width, height, rise)
    local scale = width / 1920
    local screenHeight = height / scale
    local dx, dy = self.db.barOffsetX or 0, self.db.barOffsetY or 0
    -- Keep both twelve-button banks inside the console's fixed center well.
    local size = math.min(25,24*(self.db.barWidth or 100)/100)*rise
    local function box(x, y, w, h)
        return {x=x, y=y*rise, w=w, h=h*rise}
    end
    local function bar(index, x, y)
        return {index=index, x=x+dx, y=(y+dy)*rise,
            icons=12, rows=2, iconSize=size, iconPadding=2}
    end
    return {
        variant="adept", revision=14, width=width, height=height, scale=scale,
        density=rise, screenHeight=screenHeight,
        base=box(0,0,1920,132), left=box(0,0,350,132), right=box(1300,0,620,132),
        leftWell=box(640,12,310,72), rightWell=box(970,12,310,72),
        chat=box(24,24,302,78),
        map={x=960-82*rise,y=8*rise,w=164*rise,h=164*rise},
        menuDrawer=box(374,0,244,28), bagDrawer=box(1320,0,180,22),
        itemWell=box(1320,32,164,20), utilityIconSize=18*rise, utilityY=32*rise,
        auxLeft=box(628,128,220,20), auxRight=box(1072,128,208,20),
        auxTopInset=2*rise, auxRightTop=148*rise,
        trackingWell=box(650,122,620,10),
        cast={x=0,y=218*rise}, player={x=760,y=180*rise},
        target={x=1160,y=180*rise}, party={x=680,y=274*rise+(self.db.groupHeight or 36)},
        raid={x=680,y=274*rise+(self.db.groupHeight or 36)},
        bars={bar(1,760,31),bar(2,760,94),bar(3,1160,31),bar(4,1160,94)},
    }
end

function SD:FinishAdeptLayout(layout, g, dashboardOnly, previousGeometry)
    local H, E = self.UnitLayoutHelpers, Enum.EditModeSystem
    local function anchor(system, index, point, relative, x, y)
        H.anchor(H.find(layout,system,index),point,relative,x*g.scale,y*g.scale)
    end
    local map = H.find(layout,E.Minimap)
    H.setting(map,Enum.EditModeMinimapSetting.HeaderUnderneath,0)
    anchor(E.Minimap,nil,"CENTER","BOTTOMLEFT",g.map.x+g.map.w/2,g.map.y+g.map.h/2)
    if self.db.arrangeUtility then
        anchor(E.StatusTrackingBar,1,"TOP","TOP",0,-12*g.density)
        anchor(E.StatusTrackingBar,2,"TOP","TOP",0,-26*g.density)
        anchor(E.ActionBar,11,"TOPLEFT","BOTTOMLEFT",640,168*g.density)
        for index=12,13 do
            anchor(E.ActionBar,index,"TOPRIGHT","BOTTOMLEFT",1280,148*g.density)
        end
        if not dashboardOnly then
            anchor(E.ObjectiveTracker,nil,"TOPRIGHT","TOPRIGHT",-24,-290*g.density)
        end
    end
    local compactUpgrade = previousGeometry and (previousGeometry.revision or 0)<8
    if compactUpgrade and self.db.arrangeChat then
        local chat = H.find(layout,E.ChatFrame)
        local C = Enum.EditModeChatFrameSetting
        local width, height = math.floor(g.chat.w*g.scale), math.floor(g.chat.h*g.scale)
        local values = {
            [C.WidthHundreds]=math.floor(width/100), [C.WidthTensAndOnes]=width%100,
            [C.HeightHundreds]=math.floor(height/100), [C.HeightTensAndOnes]=height%100,
        }
        anchor(E.ChatFrame,nil,"BOTTOMLEFT","BOTTOMLEFT",g.chat.x,g.chat.y)
        for _,setting in ipairs(chat and chat.settings or {}) do
            if values[setting.setting]~=nil then setting.value=values[setting.setting] end
        end
    end
    -- Geometry upgrades must reseat unit cards even during dashboard-only alignment.
    local lowerUnits = previousGeometry and (previousGeometry.revision or 0)<11
    if (not dashboardOnly or compactUpgrade or lowerUnits) and self.db.arrangeUnits then
        self:PlaceAdeptUnitAnchors(layout,g)
        if self.db.attachPlayerAuras then self:ConfigurePlayerAuras(layout,g) end
    end
    if not dashboardOnly or compactUpgrade then
        anchor(E.CastBar,nil,"BOTTOM","BOTTOM",g.cast.x,g.cast.y)
    end
end

-- Migrate the saved native profile as well as the account layout.
SD.adeptUnitAnchorRevision = 8
function SD:PlaceAdeptUnitAnchors(layout,g)
    local H, E, U = self.UnitLayoutHelpers, Enum.EditModeSystem, Enum.EditModeUnitFrameSystemIndices
    local function place(index,point,x,y)
        H.anchor(H.find(layout,E.UnitFrame,index),point,"BOTTOMLEFT",x*g.scale,y*g.scale)
        H.setting(H.find(layout,E.UnitFrame,index),Enum.EditModeUnitFrameSetting.FrameSize,80*g.scale)
    end
    place(U.Player,"CENTER",g.player.x,g.player.y)
    place(U.Target,"CENTER",g.target.x,g.target.y)
    place(U.Focus,"CENTER",550,g.player.y)
end

-- Native chat has a 120-unit height minimum. Fit that surface into the dock.
function SD:RefreshAdeptChat(g)
    if InCombatLockdown() or self.editing or not ChatFrame1 or not StoneDockCharDB then return end
    local active=g.variant=="adept" and self.db.enabled and self.db.arrangeChat and self:IsOurLayoutActive()
    if not active then
        if StoneDockCharDB.adeptChatOriginalScale then
            ChatFrame1:SetScale(StoneDockCharDB.adeptChatOriginalScale)
            StoneDockCharDB.adeptChatOriginalScale=nil
        end
        if GeneralDockManager and StoneDockCharDB.adeptDockOriginalScale then
            GeneralDockManager:SetScale(StoneDockCharDB.adeptDockOriginalScale)
            StoneDockCharDB.adeptDockOriginalScale=nil
        end
        self.adeptChatFit=nil
        return
    end
    local stamp=string.format("%s:%s:%s",g.scale,g.density,g.revision)
    local dock=GeneralDockManager
    local point,parent,relative,x,y=ChatFrame1:GetPoint(1)
    if self.adeptChatFit==stamp and math.abs(ChatFrame1:GetScale()-(self.adeptChatScale or 1))<.001
        and math.abs(ChatFrame1:GetHeight()-120)<.1 and point=="BOTTOMLEFT"
        and parent==UIParent and relative=="BOTTOMLEFT" and x==self.adeptChatX and y==self.adeptChatY then return end
    StoneDockCharDB.adeptChatOriginalScale=StoneDockCharDB.adeptChatOriginalScale or ChatFrame1:GetScale()
    if dock then
        StoneDockCharDB.adeptDockOriginalScale=StoneDockCharDB.adeptDockOriginalScale or dock:GetScale()
    end
    local topPadding,bottomPadding=4,30
    -- Include native tabs and the edit box when measuring the chat footprint.
    local function edge(frame,method)
        local fn=frame and frame[method]
        local result=fn and fn(frame)
        if type(result)=="number" and (not issecretvalue or not issecretvalue(result)) then
            return result*frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
        end
    end
    local top,bottom=edge(ChatFrame1,"GetTop"),edge(ChatFrame1,"GetBottom")
    local currentScale=ChatFrame1:GetEffectiveScale()/UIParent:GetEffectiveScale()
    local measuredTop
    if top then
        for i=1,NUM_CHAT_WINDOWS or 10 do
            local tab=_G["ChatFrame"..i.."Tab"]
            local chat=_G["ChatFrame"..i]
            if tab and tab:IsShown() and (i==1 or chat and chat.isDocked) then
                local tabBottom=edge(tab,"GetBottom")
                if tabBottom then measuredTop=math.max(measuredTop or 0,(tabBottom-top)/currentScale) end
            end
        end
    end
    if measuredTop then topPadding=math.max(0,measuredTop) end
    local editBottom=edge(ChatFrame1EditBox,"GetBottom")
    if bottom and editBottom then bottomPadding=math.max(bottomPadding,(bottom-editBottom)/currentScale) end
    topPadding,bottomPadding=math.min(topPadding,50),math.min(bottomPadding,50)
    local scale=124*g.density*g.scale/(120+topPadding+bottomPadding)
    ChatFrame1:SetScale(scale)
    if dock then dock:SetScale(scale) end
    ChatFrame1:ClearAllPoints()
    local bodyBottom=(132*g.density*g.scale)-(120+topPadding)*scale
    ChatFrame1:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",g.chat.x*g.scale/scale,bodyBottom/scale)
    ChatFrame1:SetSize(g.chat.w*g.scale/scale,120)
    -- Tab bottoms form the console rim; the tabs themselves sit above it.
    local tabBottom=edge(ChatFrame1Tab,"GetBottom")
    if tabBottom then
        local delta=132*g.density*g.scale-tabBottom
        if math.abs(delta)>.25 then
            bodyBottom=bodyBottom+delta
            ChatFrame1:ClearAllPoints()
            ChatFrame1:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",g.chat.x*g.scale/scale,bodyBottom/scale)
        end
    end
    self.adeptChatScale=scale
    self.adeptChatX,self.adeptChatY=g.chat.x*g.scale/scale,bodyBottom/scale
    self.adeptChatFit=stamp
end

function SD:GetAdeptGroupRows(groups, g)
    local result = {}
    local gap, height = 4, self.db.groupHeight
    local width = (560*self.db.groupRowWidth/100-4*gap)/5
    for i=1,groups do
        result[i]={x=g.party.x+self.db.groupOffsetX,
            y=math.max(g.party.y+self.db.groupOffsetY,(self.adeptAuraClearance or 0)+height)+(i-1)*(height+gap),
            w=width,h=height,gap=gap,side="left"}
    end
    return result
end

local function rule(parent, x, y, width, height, alpha)
    local t = parent:CreateTexture(nil,"BORDER")
    t:SetColorTexture(.76,.66,.43,alpha or .6)
    t:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",x,y)
    t:SetSize(width,height)
    SD.adeptRuleLines=SD.adeptRuleLines or {}
    SD.adeptRuleLines[#SD.adeptRuleLines+1]={texture=t,parent=parent,x=x,y=y,w=width,h=height}
    return t
end

local function label(parent, text, x, y, size, heading)
    local f = parent:CreateFontString(nil,"OVERLAY")
    f:SetFont(heading and "Fonts\\FRIZQT__.TTF" or "Fonts\\ARIALN.TTF",size,"")
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    f:SetTextColor(heading and .84 or .78,heading and .75 or .77,heading and .54 or .72)
    f:SetShadowOffset(0,-1)
    f:SetJustifyH("LEFT")
    f:SetJustifyV("TOP")
    f:SetWordWrap(false)
    f:SetText(text)
    f:SetSpacing(4)
    f.adeptPosition={x=x,y=y,size=size,heading=heading,parent=parent}
    SD.adeptTextLabels=SD.adeptTextLabels or {}
    SD.adeptTextLabels[#SD.adeptTextLabels+1]=f
    return f
end

function SD:CreateAdeptJourneyTabs(f)
    f.journeyTab="journey"
    f.journeyTabs={}
    for i,spec in ipairs({{"journey","JOURNEY",72},{"expedition","EXPEDITION",88}}) do
        local button=CreateFrame("Button",nil,f.details)
        button:SetSize(spec[3],22)
        button.caption=button:CreateFontString(nil,"OVERLAY")
        button.caption:SetAllPoints()
        button.caption:SetFont("Fonts\\ARIALN.TTF",10,"")
        button.caption:SetJustifyH("LEFT")
        button.caption:SetText(spec[2])
        button.line=button:CreateTexture(nil,"OVERLAY")
        button.line:SetColorTexture(.83,.73,.49,1)
        button.line:SetPoint("BOTTOMLEFT")
        button.line:SetPoint("BOTTOMRIGHT")
        button.line:SetHeight(2)
        local key=spec[1]
        button:SetScript("OnClick",function()
            f.journeyTab=key
            SD:RefreshAdeptJourney()
        end)
        SD:RegisterUsageButton(button,"Journey tab: "..spec[2])
        f.journeyTabs[i]=button
    end
    local view=CreateFrame("Frame",nil,f.details)
    f.expeditionView=view
    view:SetAllPoints()
    view:EnableMouse(false)
    f.expeditionTitle=label(view,"",1522,-37,11)
    f.expeditionDetail=label(view,"",1522,-54,10)
    f.expeditionCount=label(view,"",1522,-69,10)
    for _,text in ipairs({f.expeditionTitle,f.expeditionDetail,f.expeditionCount}) do text:SetWidth(164) end
    local function control(caption,action)
        local button=CreateFrame("Button",nil,view)
        button.label=button:CreateFontString(nil,"OVERLAY")
        button.label:SetAllPoints()
        button.label:SetFont("Fonts\\ARIALN.TTF",10,"")
        button.label:SetTextColor(.88,.8,.61)
        button.label:SetText(caption)
        button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
        button:GetHighlightTexture():SetVertexColor(.8,.7,.45,.08)
        button:SetScript("OnClick",function()
            if SD:IsBusy() then SD.Print("Use expedition controls outside combat and Edit Mode.") return end
            action()
            SD:RefreshExpeditionStatus()
        end)
        return button
    end
    f.expeditionConfigure=control("Setup",function() SD:OpenSettingsTab("gathering") end)
    f.expeditionStartStop=control("Start",function()
        if SD.gathering and SD.gathering.active then
            SD.fishingAutoPaused=true
            SD:StopGathering()
        else SD:StartConfiguredExpedition() end
    end)
    f.expeditionNext=control("Next stop",function()
        if SD.oreRoute then SD:AdvanceOreRoute()
        elseif SD.gathering and SD.gathering.targetID then SD:StartOreRoute(SD.gathering.targetID) end
    end)
end

function SD:RefreshAdeptJourney()
    local f=self.adeptConsole
    if not f or not f.journeyTabs then return end
    local journey=f.journeyTab~="expedition"
    for i,button in ipairs(f.journeyTabs) do
        local selected=(i==1)==journey
        button.line:SetShown(selected)
        button.caption:SetTextColor(selected and .9 or .57,selected and .83 or .57,selected and .65 or .54)
    end
    for _,widget in ipairs({f.journey,f.progress,f.caption,f.journeyAction}) do widget:SetShown(journey) end
    f.expeditionView:SetShown(not journey)
    if journey then return end
    local info=self:GetExpeditionDetails()
    f.expeditionTitle:SetText(info.active and info.title or "No expedition")
    f.expeditionDetail:SetText(info.active and info.detail or "Choose an activity in Setup")
    f.expeditionCount:SetText(info.active and info.count or "")
    f.expeditionStartStop.label:SetText(info.active and "End" or "Start")
    local enabled=not self:IsBusy()
    for _,button in ipairs({f.expeditionConfigure,f.expeditionStartStop,f.expeditionNext}) do
        button:SetEnabled(enabled)
        button:SetAlpha(enabled and 1 or .45)
    end
    f.expeditionNext:SetShown(not not (info.active and (self.oreRoute or self.gathering.targetID)))
end

function SD:CreateAdeptCompanyTabs(f)
    f.companyTab="company"
    f.companyTabs={}
    for i,spec in ipairs({{"company","COMPANY"},{"settings","SETTINGS"}}) do
        local b=CreateFrame("Button",nil,f.details)
        b:SetSize(78,22)
        b.caption=b:CreateFontString(nil,"OVERLAY")
        b.caption:SetAllPoints()
        b.caption:SetFont("Fonts\\ARIALN.TTF",10,"")
        b.caption:SetJustifyH("LEFT")
        b.caption:SetText(spec[2])
        b.line=b:CreateTexture(nil,"OVERLAY")
        b.line:SetColorTexture(.83,.73,.49,1)
        b.line:SetPoint("BOTTOMLEFT") b.line:SetPoint("BOTTOMRIGHT") b.line:SetHeight(2)
        local key=spec[1]
        b:SetScript("OnClick",function() f.companyTab=key SD:RefreshAdeptCompany() end)
        SD:RegisterUsageButton(b,"Company tab: "..spec[2])
        f.companyTabs[i]=b
    end
    f.companySettings=CreateFrame("Frame",nil,f.details)
    f.companySettings:SetAllPoints()
    f.companySettings:EnableMouse(false)
    f.companyControls={}
    for i,caption in ipairs({"","Open StoneDock config","Record usage","Export usage"}) do
        local b=CreateFrame("Button",nil,f.companySettings)
        b:SetSize(164,24)
        b.caption=b:CreateFontString(nil,"OVERLAY")
        b.caption:SetAllPoints() b.caption:SetFont("Fonts\\ARIALN.TTF",11,"")
        b.caption:SetJustifyH("LEFT") b.caption:SetTextColor(.88,.8,.61)
        b.caption:SetText(caption)
        b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
        b:GetHighlightTexture():SetVertexColor(.8,.7,.45,.08)
        local action=i
        b:SetScript("OnClick",function()
            if SD:IsBusy() then SD.Print("Use layout settings outside combat and Edit Mode.") return end
            if action==1 then
                SD.db.adeptShowBagBar=not SD.db.adeptShowBagBar
                SD:RefreshVariantControls()
            elseif action==2 then SD:OpenSettingsTab(SD.settingsTab or "master")
            elseif action==3 then SD:UsageCommand(SD:IsUsageRecording() and "stop" or "start")
            else SD:UsageCommand("export") end
            SD:RefreshAdeptCompany()
        end)
        SD:RegisterUsageButton(b,({"Bag bar visibility","StoneDock config","Usage recording","Usage export"})[i])
        f.companyControls[i]=b
    end
end

function SD:RefreshAdeptCompany()
    local f=self.adeptConsole
    if not f or not f.companyTabs then return end
    local company=f.companyTab~="settings"
    for i,b in ipairs(f.companyTabs) do
        local selected=(i==1)==company
        b.line:SetShown(selected)
        b.caption:SetTextColor(selected and .9 or .57,selected and .83 or .57,selected and .65 or .54)
    end
    f.company:SetShown(company)
    f.companyAction:SetShown(company)
    f.companySettings:SetShown(not company)
    f.companyControls[1].caption:SetText("Bag bar: "..(self.db.adeptShowBagBar and "Shown" or "Hidden"))
    f.companyControls[3].caption:SetText(self:IsUsageRecording() and "Stop recording" or "Record usage")
    for _,b in ipairs(f.companyControls) do
        b:SetEnabled(not self:IsBusy())
        b:SetAlpha(self:IsBusy() and .45 or 1)
    end
end

function SD:RefreshAdeptArt(g)
    self:RefreshAdeptChat(g)
    local show = g.variant=="adept" and self.db.enabled
        and (self:IsOurLayoutActive() or self.db.showGuides)
    if not self.adeptConsole then
        if not show then return end
        local f = CreateFrame("Frame",nil,self.canvas)
        self.adeptConsole = f
        f:EnableMouse(false)
        f:SetFrameLevel(2)
        f.fill = f:CreateTexture(nil,"BACKGROUND")
        f.fill:SetAllPoints()
        f.fill:SetColorTexture(.0925,.0945,.096,1)
        f.grain = f:CreateTexture(nil,"BACKGROUND",nil,1)
        f.grain:SetAllPoints()
        f.grain:SetTexture("Interface\\AddOns\\StoneDock\\Media\\AdeptSurface","REPEAT","REPEAT")
        f.grain:SetTexCoord(0,8,0,1)
        f.grain:SetVertexColor(.32,.33,.34,.32)
        f.top = rule(f,0,131,1920,1,.8)
        rule(f,0,0,1920,1,.5)
        rule(f,0,0,1,132,.45)
        rule(f,1919,0,1,132,.45)
        rule(f,0,131,350,1,.8)
        f.details = CreateFrame("Frame",nil,f)
        f.details:SetAllPoints()
        local d = f.details
        for _, x in ipairs({350,630,1295,1500,1710}) do rule(d,x,36,1,80,.16) end
        label(d,"AT A GLANCE",374,-14,10)
        label(d,"READY",1320,-14,10)
        f.status = label(d,"Gold\nFramerate\nLatency",374,-37,11)
        f.statusValues = label(d,"",478,-37,11)
        f.statusValues:SetWidth(136)
        f.statusValues:SetJustifyH("RIGHT")
        f.readiness = label(d,"Gear\nBag space",1320,-37,11)
        f.readinessValues = label(d,"",1416,-37,11)
        f.readinessValues:SetWidth(74)
        f.readinessValues:SetJustifyH("RIGHT")
        f.journey = label(d,"",1522,-37,12)
        f.company = label(d,"",1732,-37,12)
        f.status:SetWidth(244)
        f.readiness:SetWidth(170)
        f.journey:SetWidth(170)
        f.company:SetWidth(164)
        for _,text in ipairs({f.status,f.statusValues,f.readiness,f.readinessValues,f.company}) do
            text:SetWordWrap(true)
            text:SetHeight(64)
        end
        for _,x in ipairs({374,1320,1522,1732}) do
            rule(d,x,102,x==374 and 240 or 164,1,.16)
        end
        f.progress = CreateFrame("StatusBar",nil,d)
        f.progress:SetPoint("TOPLEFT",d,"TOPLEFT",1522,-65)
        f.progress:SetSize(164,3)
        f.progress:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        f.progress:SetStatusBarColor(.81,.72,.5)
        f.progress.track = f.progress:CreateTexture(nil,"BACKGROUND")
        f.progress.track:SetAllPoints()
        f.progress.track:SetColorTexture(.12,.12,.11,1)
        f.caption = label(d,"",1522,-78,11)
        f.caption:SetWidth(164)
        local function action(x, width, title, hint, callback)
            local b = CreateFrame("Button",nil,d)
            b:SetPoint("TOPLEFT",x,-10)
            b:SetSize(width,86)
            b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
            b:GetHighlightTexture():SetVertexColor(.8,.7,.45,.045)
            b:SetScript("OnEnter",function(owner)
                GameTooltip:SetOwner(owner,"ANCHOR_TOP")
                GameTooltip:SetText(title)
                GameTooltip:AddLine(hint,.8,.8,.75,true)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave",function() GameTooltip:Hide() end)
            b:SetScript("OnClick",function()
                if not InCombatLockdown() then callback() end
            end)
            SD:RegisterUsageButton(b,title)
            return b
        end
        action(374,244,"At a glance","Open session statistics.",function() SD:OpenSettingsTab("session") end)
        local gear=action(1320,170,"Equipment","Open equipment and character details.",function() if ToggleCharacter then ToggleCharacter("PaperDollFrame") end end)
        f.gearButton=gear
        gear:SetHeight(22)
        gear:ClearAllPoints()
        gear:SetPoint("TOPLEFT",d,"TOPLEFT",1320,-34)
        local bags=action(1320,170,"Bag space","Left-click to open bags. Right-click to show or hide the bag bar.",function()end)
        f.bagsButton=bags
        bags:SetHeight(24)
        bags:ClearAllPoints()
        bags:SetPoint("TOPLEFT",d,"TOPLEFT",1320,-53)
        bags:RegisterForClicks("LeftButtonUp","RightButtonUp")
        bags:SetScript("OnClick",function(_,button)
            if InCombatLockdown() then SD.Print("Use bag controls after combat.") return end
            if button=="RightButton" then
                SD.db.adeptShowBagBar=not SD.db.adeptShowBagBar
                SD:RefreshVariantControls()
            elseif ToggleAllBags then ToggleAllBags() end
        end)
        f.journeyAction=action(1522,170,"Journey","Open session progress.",function() SD:OpenSettingsTab("session") end)
        f.companyAction=action(1732,164,"Company","Open friends and social tools.",function() if ToggleFriendsFrame then ToggleFriendsFrame() end end)
        self:CreateAdeptJourneyTabs(f)
        self:CreateAdeptCompanyTabs(f)
    end
    local f = self.adeptConsole
    f:SetShown(show)
    if not show then return end
    f:ClearAllPoints()
    f:SetPoint("BOTTOMLEFT",self.canvas,"BOTTOMLEFT",0,0)
    f:SetSize(1920,132*g.density)
    f.gearButton:ClearAllPoints()
    f.gearButton:SetPoint("TOPLEFT",f.details,"TOPLEFT",1320,-34*g.density)
    f.gearButton:SetHeight(19*g.density)
    f.bagsButton:ClearAllPoints()
    f.bagsButton:SetPoint("TOPLEFT",f.details,"TOPLEFT",1320,-53*g.density)
    f.bagsButton:SetHeight(24*g.density)
    for i,button in ipairs(f.journeyTabs) do
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT",f.details,"TOPLEFT",1522+(i-1)*78,-9*g.density)
        button:SetHeight(22*g.density)
    end
    for i,b in ipairs(f.companyTabs) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT",f.details,"TOPLEFT",1732+(i-1)*84,-9*g.density)
        b:SetHeight(22*g.density)
    end
    f.companyAction:ClearAllPoints()
    f.companyAction:SetPoint("TOPLEFT",f.details,"TOPLEFT",1732,-34*g.density)
    f.companyAction:SetHeight(64*g.density)
    for i,b in ipairs(f.companyControls) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT",f.companySettings,"TOPLEFT",1732,-(34+(i-1)*22)*g.density)
        b:SetHeight(20*g.density)
    end
    f.journeyAction:ClearAllPoints()
    f.journeyAction:SetPoint("TOPLEFT",f.details,"TOPLEFT",1522,-34*g.density)
    f.journeyAction:SetHeight(64*g.density)
    for i,button in ipairs({f.expeditionConfigure,f.expeditionStartStop,f.expeditionNext}) do
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT",f.expeditionView,"TOPLEFT",1522+(i==2 and 84 or 0),-(i==3 and 111 or 88)*g.density)
        button:SetSize(i==3 and 164 or 80,18*g.density)
    end
    for _,spec in ipairs(self.adeptRuleLines or {}) do
        spec.texture:ClearAllPoints()
        spec.texture:SetPoint("BOTTOMLEFT",spec.parent,"BOTTOMLEFT",spec.x,spec.y*g.density)
        spec.texture:SetSize(spec.w,spec.h==1 and 1 or spec.h*g.density)
    end
    for _,text in ipairs(self.adeptTextLabels or {}) do
        local spec=text.adeptPosition
        if spec then
            text:ClearAllPoints()
            text:SetPoint("TOPLEFT",spec.parent,"TOPLEFT",spec.x,spec.y*g.density)
            text:SetFont(spec.heading and "Fonts\\FRIZQT__.TTF" or "Fonts\\ARIALN.TTF",
                math.max(9,spec.size*math.max(.85,g.density)),"")
            text:SetSpacing(4*g.density)
        end
    end
    f.progress:ClearAllPoints()
    f.progress:SetPoint("TOPLEFT",f.details,"TOPLEFT",1522,-65*g.density)
    f.top:ClearAllPoints()
    f.top:SetPoint("TOPLEFT",f,"TOPLEFT",350,0)
    f.top:SetPoint("TOPRIGHT")
    f.top:SetHeight(1)
    self:UpdateAdeptConsole()
    self:RefreshAdeptCombat()
end

local function value(fn, ...)
    local n = fn and fn(...)
    if type(n)=="number" and (not issecretvalue or not issecretvalue(n)) then return n end
    return 0
end

function SD:UpdateAdeptConsole()
    local f = self.adeptConsole
    if not f or not f:IsShown() then return end
    local free, durability = 0, 100
    if C_Container and C_Container.GetContainerNumFreeSlots then
        for bag=0,NUM_BAG_SLOTS or 4 do
            free = free + value(C_Container.GetContainerNumFreeSlots,bag)
        end
    end
    if GetInventoryItemDurability then
        for slot=1,19 do
            local current, maximum = GetInventoryItemDurability(slot)
            if type(current)=="number" and type(maximum)=="number"
                and (not issecretvalue or not (issecretvalue(current) or issecretvalue(maximum)))
                and maximum>0 then durability=math.min(durability,current/maximum*100) end
        end
    end
    local gold = math.floor(value(GetMoney)/10000)
    local latency = 0
    if GetNetStats then latency=value(function()return select(3,GetNetStats())end) end
    f.statusValues:SetText(string.format("%s g\n%d fps\n%d ms",gold,math.floor(value(GetFramerate)),latency))
    f.readinessValues:SetText(string.format("%d%%\n%d free",math.floor(durability),free))
    local xp, maximum = value(UnitXP,"player"), value(UnitXPMax,"player")
    f.journey:SetText("Level "..value(UnitLevel,"player"))
    f.progress:SetMinMaxValues(0,math.max(1,maximum))
    f.progress:SetValue(xp)
    f.caption:SetText(maximum>0 and string.format("%d%%  •  %d rested",math.floor(xp/maximum*100),value(GetXPExhaustion)) or "Level complete")
    local members = value(GetNumGroupMembers)
    local friends = C_FriendList and value(C_FriendList.GetNumOnlineFriends) or 0
    f.company:SetText((members>0 and (members.." in group") or "Traveling alone").."\n"..friends.." friends online")
    f.details:SetShown(self.db.showInfo)
    self:RefreshAdeptJourney()
    self:RefreshAdeptCompany()
end

function SD:RefreshAdeptCombat()
    if self.adeptConsole then
        local combat = InCombatLockdown() and not self.editing
        self.adeptConsole.details:SetAlpha(combat and .15 or 1)
        self.adeptConsole.details:EnableMouse(false)
        self:RefreshAdeptCompany()
    end
    if self.layoutName=="Adept" and self.RefreshHUD then self:RefreshHUD() end
end

SD:On("PLAYER_REGEN_DISABLED",function() SD:RefreshAdeptCombat() end)
SD:On("PLAYER_REGEN_ENABLED",function() SD:RefreshAdeptCombat() end)
