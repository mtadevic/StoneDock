local _, SD = ...
local cards = {}
function SD:GetAdeptUnitCards() return cards end
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
    local count=frame.GetNumPoints and frame:GetNumPoints()
    if type(count)~="number" or (issecretvalue and issecretvalue(count)) then return end
    if count<0 or count>32 or count~=math.floor(count) then return end
    local points={}
    for i=1,count do points[i]={frame:GetPoint(i)} end
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
    if icon and castSeats[cast] and castSeats[cast].icon then
        icon:SetSize(10,10)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT",cast,"RIGHT",3,0)
    end
    cast.stoneDockSeating=nil
end

function SD:SeatAdeptCastBar(cast,card)
    if not cast then return end
    local saved=castSeats[cast]
    if not saved or not saved.card then
        -- During native frame reconstruction GetNumPoints may not yet return
        -- a readable count. Do not move a bar whose original state cannot be saved.
        local points=savePoints(cast)
        if not points then return end
        local w,h,scale=cast:GetWidth(),cast:GetHeight(),cast:GetScale()
        for _,value in ipairs({w,h,scale}) do
            if type(value)~="number" or (issecretvalue and issecretvalue(value)) then return end
        end
        if not w or not h or not scale or w<=0 or h<=0 or scale<=0 then return end
        local fresh=not saved
        saved=saved or {}
        saved.points,saved.w,saved.h,saved.scale=points,w,h,scale
        castSeats[cast]=saved
        if fresh then
            cast:HookScript("OnShow",function() seatCast(cast,saved.card) end)
            if hooksecurefunc then hooksecurefunc(cast,"SetPoint",function() seatCast(cast,saved.card) end) end
        end
    end
    local icon=cast.Icon or cast.icon
    if icon and not saved.icon then
        local points=savePoints(icon)
        if points then saved.icon={frame=icon,w=icon:GetWidth(),h=icon:GetHeight(),points=points} end
    end
    saved.card=card
    seatCast(cast,card)
end

function SD:FitAdeptPlayerAuraLane(aura,card,debuff)
    local bounds=self:GetVisibleArtworkBounds(aura)
    if not bounds or not card.GetRect then return end
    local x,y,w,h=card:GetRect()
    local scale=card:GetEffectiveScale()/UIParent:GetEffectiveScale()
    if not x or not y or not w or not h then return end
    x,y,w,h=x*scale,y*scale,w*scale,h*scale
    local gap=4*self:GetGeometry().scale
    local desiredX=debuff and (x-gap-bounds.w) or x
    local desiredY=y+h+gap
    local dx,dy=desiredX-bounds.x,desiredY-bounds.y
    if math.abs(dx)<.25 and math.abs(dy)<.25 then return end
    local point,parent,relative,oldX,oldY=aura:GetPoint(1)
    if not point then return end
    local factor=aura:GetEffectiveScale()/UIParent:GetEffectiveScale()
    aura:ClearAllPoints()
    aura:SetPoint(point,parent,relative,(oldX or 0)+dx/factor,(oldY or 0)+dy/factor)
end

function SD:RefreshAdeptAuraClearance()
    local g=self:GetGeometry()
    local top=0
    local left=(g.party.x+(self.db.groupOffsetX or 0))*g.scale
    local right=left+560*(self.db.groupRowWidth or 100)/100*g.scale
    for _,aura in pairs({BuffFrame,DebuffFrame}) do
        local bounds=self:GetVisibleArtworkBounds(aura)
        if bounds and bounds.x<right and bounds.right>left then top=math.max(top,bounds.top/g.scale+8) end
    end
    if math.abs((self.adeptAuraClearance or 0)-top)>.25 then
        self.adeptAuraClearance=top
        self:QueueRaidSplit()
    end
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
    card.pvp=card:CreateTexture(nil,"OVERLAY",nil,4)
    card.pvp:SetSize(20,20)
    card.pvp:SetPoint("BOTTOMRIGHT",card,"BOTTOMRIGHT",-2,4)
    card.pvp:Hide()
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
    if unit=="pet" then
        card.happinessIcon=card:CreateTexture(nil,"OVERLAY")
        card.happinessIcon:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness")
        card.happinessIcon:SetSize(10,10)
        card.happinessIcon:SetPoint("BOTTOMLEFT",8,1)
        card.happinessIcon:Hide()
        card.happiness=text(card,9)
        card.happiness:SetPoint("BOTTOMLEFT",22,1)
        card.happiness:SetWidth(82)
    end
    return card
end

function SD:UpdateAdeptUnitCards(event,changed)
    if not active then return end
    if issecretvalue and issecretvalue(changed) then return end
    for _,card in pairs(cards) do
        local unit=card.unit
        if not changed or changed==unit or event=="UNIT_TARGET" or event=="UNIT_FACTION" or event=="PLAYER_FLAGS_CHANGED" or (unit=="pet" and event=="UNIT_PET" and changed=="player") then
            -- These badges are artwork only; native unit-frame clicks stay intact.
            local flagged=UnitIsPVP and UnitIsPVP(unit)
            local ffa=UnitIsPVPFreeForAll and UnitIsPVPFreeForAll(unit)
            local faction=UnitFactionGroup and UnitFactionGroup(unit)
            local readable=not issecretvalue or not (issecretvalue(flagged) or issecretvalue(ffa) or issecretvalue(faction))
            local icon
            if readable then
                if ffa then icon="FFA"
                elseif flagged and (faction=="Alliance" or faction=="Horde") then icon=faction end
            end
            card.pvp:SetShown(icon~=nil)
            card.pvp:SetTexture(icon and ("Interface\\TargetingFrame\\UI-PVP-"..icon) or nil)
            if card.happiness then
                local happiness=GetPetHappiness and GetPetHappiness()
                local readable=type(happiness)=="number" and (not issecretvalue or not issecretvalue(happiness))
                local valid=readable and (happiness==1 or happiness==2 or happiness==3)
                card.happiness:SetText(valid and ({"Unhappy","Content","Happy"})[happiness] or "")
                card.happinessIcon:SetShown(not not valid)
                if valid then
                    local offset=(3-happiness)*.1875
                    card.happinessIcon:SetTexCoord(offset,offset+.1875,0,.359375)
                    local colors={{1,.35,.3},{1,.82,.25},{.45,.9,.45}}
                    card.happiness:SetTextColor(unpack(colors[happiness]))
                end
            end
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
        self.adeptAuraClearance=nil
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
        {PlayerFrame,"player"},{TargetFrame,"target"},{FocusFrame,"focus",true},{PetFrame,"pet",true},
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
                        aura:SetPoint(i==1 and "BOTTOMLEFT" or "BOTTOMRIGHT",cards[frame],"TOPLEFT",i==1 and 0 or -8,3)
                        self:FitAdeptPlayerAuraLane(aura,cards[frame],i==2)
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
        "UNIT_NAME_UPDATE","UNIT_PORTRAIT_UPDATE","UNIT_TARGET","PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED",
        "UNIT_FACTION","PLAYER_FLAGS_CHANGED","PLAYER_ENTERING_WORLD","UNIT_PET"}) do
        self.adeptUnitEvents:RegisterEvent(event)
    end
    if GetPetHappiness then self.adeptUnitEvents:RegisterEvent("UNIT_HAPPINESS") end
    self:UpdateAdeptUnitCards()
    self:RefreshAdeptAuraClearance()
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
    if (not issecretvalue or not issecretvalue(unit)) and (unit=="player" or unit=="target" or unit=="focus") then SD:QueueAdeptUnitFrameRefresh() end
end)

SD:On("UNIT_PET",function(unit) if unit=="player" then SD:QueueAdeptUnitFrameRefresh() end end)
