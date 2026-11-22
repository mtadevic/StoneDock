local _, SD = ...
local cards = {}
local originalAlpha = {}
local auraPoints = {}
local alphaHooks = setmetatable({}, {__mode="k"})
local active
local maskPath = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function text(parent,size)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont("Fonts\\FRIZQT__.TTF",size,"")
    f:SetTextColor(.88,.84,.73)
    f:SetJustifyH("LEFT")
    f:SetWordWrap(false)
    return f
end

local function circle(parent,size,r,g,b,layer)
    local t=parent:CreateTexture(nil,"ARTWORK",nil,layer)
    t:SetTexture(maskPath)
    t:SetVertexColor(r,g,b,1)
    t:SetSize(size,size)
    return t
end

local castSeats={}
local function savePoints(frame)
    local points={}
    for i=1,frame:GetNumPoints() do points[i]={frame:GetPoint(i)} end
    return points
end
local function restorePoints(frame,points)
    frame:ClearAllPoints()
    for _,point in ipairs(points) do frame:SetPoint(unpack(point)) end
end
local function seatCast(cast,card)
    if not active or not card or cast.stoneDockSeating then return end
    if InCombatLockdown() and cast.IsProtected and cast:IsProtected() then SD.adeptUnitRefreshAfterCombat=true return end
    cast.stoneDockSeating=true
    local parent=cast:GetParent() or UIParent
    cast:SetScale(card:GetEffectiveScale()/parent:GetEffectiveScale())
    cast:SetSize(card:GetWidth()-56,10)
    cast:ClearAllPoints()
    cast:SetPoint("BOTTOMLEFT",card,"BOTTOMLEFT",8,1)
    local icon=cast.Icon or cast.icon
    if icon then
        icon:SetSize(10,10)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT",cast,"RIGHT",3,0)
    end
    cast.stoneDockSeating=nil
end

function SD:SeatAdeptCastBar(cast,card)
    if not cast then return end
    local saved=castSeats[cast]
    if not saved then
        saved={points={},w=cast:GetWidth(),h=cast:GetHeight(),scale=cast:GetScale()}
        for i=1,cast:GetNumPoints() do saved.points[i]={cast:GetPoint(i)} end
        castSeats[cast]=saved
        cast:HookScript("OnShow",function() seatCast(cast,saved.card) end)
        if hooksecurefunc then
            hooksecurefunc(cast,"SetPoint",function() seatCast(cast,saved.card) end)
        end
    end
    if not saved.card then
        saved.points={}
        for i=1,cast:GetNumPoints() do saved.points[i]={cast:GetPoint(i)} end
        saved.w,saved.h,saved.scale=cast:GetWidth(),cast:GetHeight(),cast:GetScale()
    end
    local icon=cast.Icon or cast.icon
    if icon and not saved.icon then saved.icon={frame=icon,w=icon:GetWidth(),h=icon:GetHeight(),points=savePoints(icon)} end
    saved.card=card
    seatCast(cast,card)
end

local function create(frame,unit,compact)
    local card=CreateFrame("Frame",nil,frame,"BackdropTemplate")
    card.stoneDockAdeptCard=true
    card:EnableMouse(false)
    card:SetFrameLevel(frame:GetFrameLevel()+6)
    card:SetSize(compact and 156 or 220,60)
    card:SetPoint("CENTER",frame,"CENTER")
    card:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    card:SetBackdropColor(.08,.082,.085,.98)
    card:SetBackdropBorderColor(.69,.6,.4,.9)
    card.unit=unit
    local diameter=40
    local rim=circle(card,diameter,.75,.65,.43,1)
    rim:SetPoint("CENTER",card,"RIGHT",-25,0)
    local inset=circle(card,diameter-4,.035,.037,.04,2)
    inset:SetPoint("CENTER",rim,"CENTER")
    card.portrait=card:CreateTexture(nil,"ARTWORK",nil,3)
    card.portrait:SetSize(diameter-8,diameter-8)
    card.portrait:SetPoint("CENTER",rim,"CENTER")
    local mask=card:CreateMaskTexture(nil,"ARTWORK")
    mask:SetTexture(maskPath,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(card.portrait)
    card.portrait:AddMaskTexture(mask)
    card.level=text(card,compact and 9 or 10)
    card.level:SetPoint("TOP",rim,"BOTTOM",0,4)
    local heading=text(card,compact and 8 or 9)
    heading:SetPoint("TOPLEFT",8,-5)
    heading:SetText(unit=="targettarget" and "TARGET OF TARGET" or unit:upper())
    heading:SetTextColor(.67,.66,.61)
    card.name=text(card,compact and 11 or 13)
    card.name:SetPoint("TOPLEFT",8,-17)
    card.name:SetWidth(compact and 100 or 164)
    card.health=CreateFrame("StatusBar",nil,card)
    card.health:SetPoint("TOPLEFT",8,-35)
    card.health:SetSize(compact and 100 or 164,8)
    card.health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    card.health:SetStatusBarColor(.86,.82,.7,1)
    local track=card.health:CreateTexture(nil,"BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(.17,.17,.16,1)
    card.number=text(card.health,compact and 8 or 10)
    card.number:SetPoint("LEFT",4,0)
    card.number:SetTextColor(.06,.065,.07)
    card.power=CreateFrame("StatusBar",nil,card)
    card.power:SetPoint("TOPLEFT",card.health,"BOTTOMLEFT",0,-3)
    card.power:SetSize(compact and 100 or 164,2)
    card.power:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    card.power:SetStatusBarColor(.43,.58,.77,1)
    return card
end

function SD:UpdateAdeptUnitCards(event,changed)
    if not active then return end
    if issecretvalue and issecretvalue(changed) then return end
    for _,card in pairs(cards) do
        local unit=card.unit
        if not changed or changed==unit or event=="UNIT_TARGET" then
            -- Native UI renderers accept opaque values directly.
            card.health:SetMinMaxValues(0,UnitHealthMax(unit))
            card.health:SetValue(UnitHealth(unit))
            card.number:SetText(UnitHealth(unit))
            card.power:SetMinMaxValues(0,UnitPowerMax(unit))
            card.power:SetValue(UnitPower(unit))
            if UnitPowerType then
                local kind,token=UnitPowerType(unit)
                if not issecretvalue or not (issecretvalue(kind) or issecretvalue(token)) then
                    local color=PowerBarColor and (PowerBarColor[token] or PowerBarColor[kind])
                    if color then card.power:SetStatusBarColor(color.r,color.g,color.b,1) end
                end
            end
            if not event or event=="PLAYER_TARGET_CHANGED" or event=="PLAYER_FOCUS_CHANGED"
                or event=="UNIT_TARGET" or event=="UNIT_PORTRAIT_UPDATE" or event=="UNIT_NAME_UPDATE" then
                card.name:SetText(UnitName(unit))
                card.level:SetText(UnitLevel(unit))
                if SetPortraitTexture then SetPortraitTexture(card.portrait,unit) end
            end
        end
    end
end

function SD:RefreshAdeptUnitFrames(enabled)
    if InCombatLockdown() then return end
    active=enabled and not self.editing
    if not active then
        for region,alpha in pairs(originalAlpha) do region:SetAlpha(alpha) end
        originalAlpha={}
        for cast,saved in pairs(castSeats) do
            if saved.card then
                cast:SetScale(saved.scale)
                cast:SetSize(saved.w,saved.h)
                cast:ClearAllPoints()
                for _,point in ipairs(saved.points) do cast:SetPoint(unpack(point)) end
                if saved.icon then
                    local icon=saved.icon
                    icon.frame:SetSize(icon.w,icon.h)
                    restorePoints(icon.frame,icon.points)
                    saved.icon=nil
                end
                saved.card=nil
            end
        end
        for button,points in pairs(auraPoints) do
            button:ClearAllPoints()
            for _,point in ipairs(points) do button:SetPoint(unpack(point)) end
        end
        auraPoints={}
        for frame,card in pairs(cards) do
            card:Hide()
            if card.originalPoints then
                frame:ClearAllPoints()
                for _,point in ipairs(card.originalPoints) do frame:SetPoint(unpack(point)) end
                card.originalPoints=nil
            end
        end
        if self.adeptUnitEvents then self.adeptUnitEvents:UnregisterAllEvents() end
        return
    end
    local entries={
        {PlayerFrame,"player"},{TargetFrame,"target"},{FocusFrame,"focus",true},
        {TargetFrameToT or (TargetFrame and (TargetFrame.totFrame or TargetFrame.ToT)),"targettarget",true},
    }
    local roots={}
    for _,entry in ipairs(entries) do
        local frame=entry[1]
        if frame then
            roots[frame]=true
            local name=frame.GetName and frame:GetName()
            for _,cast in pairs({frame.spellbar,frame.SpellBar,frame.CastBar,name and _G[name.."SpellBar"]}) do
                roots[cast]=true
            end
        end
    end
    local function suppress(root,owner,depth)
        if not root or root.stoneDockAdeptCard or depth>5 or (root~=owner and roots[root]) then return end
        if root.GetRegions then
            for _,region in ipairs({root:GetRegions()}) do
                if originalAlpha[region]==nil then originalAlpha[region]=region:GetAlpha() end
                if hooksecurefunc and not alphaHooks[region] and region.SetAlpha then
                    alphaHooks[region]=true
                    hooksecurefunc(region,"SetAlpha",function(texture,alpha)
                        -- Native rest/combat animations can restore alpha after a refresh.
                        if active and originalAlpha[texture]~=nil and alpha~=0 then texture:SetAlpha(0) end
                    end)
                end
                region:SetAlpha(0)
            end
        end
        if root.GetChildren then
            for _,child in ipairs({root:GetChildren()}) do
                -- Preserve actual aura buttons, rather than every native button.
                local name=child.GetName and child:GetName()
                local aura=name and (name:match("Buff%d+$") or name:match("Debuff%d+$"))
                if not aura then suppress(child,owner,depth+1) end
            end
        end
    end
    for _,entry in ipairs(entries) do
        local frame,unit,compact=entry[1],entry[2],entry[3]
        if frame then
            if not cards[frame] then cards[frame]=create(frame,unit,compact) end
            local g=self:GetGeometry()
            local nativeScale=frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
            -- Native Edit Mode size sliders clamp; keep our art fitted even at that limit.
            cards[frame]:SetScale(.8*g.scale*g.density/nativeScale)
            if unit=="targettarget" and TargetFrame then
                if not cards[frame].originalPoints then cards[frame].originalPoints=savePoints(frame) end
                frame:ClearAllPoints()
                local factor=frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
                local half=cards[frame]:GetWidth()*cards[frame]:GetEffectiveScale()/UIParent:GetEffectiveScale()/2
                frame:SetPoint("CENTER",cards[TargetFrame] or TargetFrame,"RIGHT",(half+12*g.scale*g.density)/factor,0)
            end
            if unit=="targettarget" and not cards[frame].showHooked then
                frame:HookScript("OnShow",function() SD:QueueAdeptUnitFrameRefresh() end)
                cards[frame].showHooked=true
            end
            if unit=="player" and not self.db.attachPlayerAuras then
                for _,aura in pairs({BuffFrame,DebuffFrame}) do
                    if aura and auraPoints[aura] then restorePoints(aura,auraPoints[aura]) auraPoints[aura]=nil end
                end
            end
            if unit=="player" and self.db.attachPlayerAuras then
                for i,aura in pairs({BuffFrame,DebuffFrame}) do
                    if aura then
                        if not auraPoints[aura] then
                            auraPoints[aura]={}
                            for j=1,aura:GetNumPoints() do auraPoints[aura][j]={aura:GetPoint(j)} end
                        end
                        aura:ClearAllPoints()
                        aura:SetPoint("BOTTOMLEFT",cards[frame],"TOPLEFT",0,i==1 and 3 or 25)
                    end
                end
            end
            if unit=="target" or unit=="focus" then
                local prefix=frame:GetName()
                local buffRows=0
                for i=1,32 do
                    local button=prefix and _G[prefix.."Buff"..i]
                    if button and button:IsShown() then buffRows=math.max(buffRows,math.ceil(i/10)) end
                end
                for _,kind in ipairs({"Buff","Debuff"}) do
                    for i=1,32 do
                        local button=prefix and _G[prefix..kind..i]
                        if button then
                            if not auraPoints[button] then
                                auraPoints[button]={}
                                for j=1,button:GetNumPoints() do auraPoints[button][j]={button:GetPoint(j)} end
                            end
                            button:ClearAllPoints()
                            button:SetPoint("BOTTOMLEFT",cards[frame],"TOPLEFT",((i-1)%10)*21,3+math.floor((i-1)/10)*23+(kind=="Debuff" and buffRows*23 or 0))
                        end
                    end
                end
            end
            if unit=="target" or unit=="focus" then
                local name=frame:GetName()
                local cast=frame.spellbar or frame.SpellBar or frame.CastBar or (name and _G[name.."SpellBar"])
                self:SeatAdeptCastBar(cast,cards[frame])
            end
            suppress(frame,frame,0)
            cards[frame]:Show()
        end
    end
    if not self.adeptUnitEvents then
        self.adeptUnitEvents=CreateFrame("Frame")
        self.adeptUnitEvents:SetScript("OnEvent",function(_,event,unit) SD:UpdateAdeptUnitCards(event,unit) end)
    end
    self.adeptUnitEvents:UnregisterAllEvents()
    for _,event in ipairs({"UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_POWER_UPDATE","UNIT_MAXPOWER",
        "UNIT_NAME_UPDATE","UNIT_PORTRAIT_UPDATE","UNIT_TARGET","PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED"}) do
        self.adeptUnitEvents:RegisterEvent(event)
    end
    self:UpdateAdeptUnitCards()
end

function SD:QueueAdeptUnitFrameRefresh()
    if not self.db or not self.db.enabled or self.layoutName~="Adept" then return end
    if InCombatLockdown() then self.adeptUnitRefreshAfterCombat=true return end
    if self.adeptUnitRefreshQueued then return end
    self.adeptUnitRefreshQueued=true
    C_Timer.After(0,function()
        SD.adeptUnitRefreshQueued=nil
        if InCombatLockdown() then SD.adeptUnitRefreshAfterCombat=true return end
        local enabled=SD.db and SD.db.enabled and SD.layoutName=="Adept" and SD:IsOurLayoutActive()
        SD:RefreshAdeptUnitFrames(enabled)
    end)
end

SD:On("PLAYER_TARGET_CHANGED",function() SD:QueueAdeptUnitFrameRefresh() end)
SD:On("PLAYER_FOCUS_CHANGED",function() SD:QueueAdeptUnitFrameRefresh() end)
SD:On("UNIT_TARGET",function(unit)
    if (not issecretvalue or not issecretvalue(unit)) and unit=="target" then SD:QueueAdeptUnitFrameRefresh() end
end)
SD:On("CVAR_UPDATE",function(name)
    if name=="showTargetOfTarget" then SD:QueueAdeptUnitFrameRefresh() end
end)
SD:On("PLAYER_REGEN_ENABLED",function()
    if SD.adeptUnitRefreshAfterCombat then
        SD.adeptUnitRefreshAfterCombat=nil
        SD:QueueAdeptUnitFrameRefresh()
    end
end)

SD:On("PLAYER_UPDATE_RESTING",function() SD:QueueAdeptUnitFrameRefresh() end)

SD:On("UNIT_AURA",function(unit)
    if (not issecretvalue or not issecretvalue(unit)) and (unit=="target" or unit=="focus") then SD:QueueAdeptUnitFrameRefresh() end
end)
