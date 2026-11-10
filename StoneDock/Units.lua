local _, SD = ...
local styled = setmetatable({}, {__mode="k"})

-- Decoration only: no health inspection, secure attributes, or replacement clicks.
local function trim(frame,show)
    if not frame or not frame.CreateTexture then return end
    if not styled[frame] then
        local edges = {}
        for i=1,4 do
            local t = frame:CreateTexture(nil,"BACKGROUND",nil,-8)
            t:SetColorTexture(0.18,0.22,0.26,1)
            if i <= 2 then
                t:SetPoint(i==1 and "TOPLEFT" or "BOTTOMLEFT",frame,i==1 and "TOPLEFT" or "BOTTOMLEFT",-3,i==1 and 3 or -3)
                t:SetPoint(i==1 and "TOPRIGHT" or "BOTTOMRIGHT",frame,i==1 and "TOPRIGHT" or "BOTTOMRIGHT",3,i==1 and 3 or -3)
                t:SetHeight(3)
            else
                t:SetPoint(i==3 and "TOPLEFT" or "TOPRIGHT",frame,i==3 and "TOPLEFT" or "TOPRIGHT",i==3 and -3 or 3,3)
                t:SetPoint(i==3 and "BOTTOMLEFT" or "BOTTOMRIGHT",frame,i==3 and "BOTTOMLEFT" or "BOTTOMRIGHT",i==3 and -3 or 3,-3)
                t:SetWidth(3)
            end
            edges[i]=t
        end
        styled[frame]=edges
    end
    local gulveig=SD.layoutName=="Gulveig Bar"
    if gulveig and show and not frame.stoneDockGroupTrim then
        frame.stoneDockGroupTrim=SD:CreateGulveigBorder(frame)
        frame.stoneDockGroupTrim:SetPoint("TOPLEFT",frame,"TOPLEFT",-4,6)
        frame.stoneDockGroupTrim:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",4,-6)
    end
    if frame.stoneDockGroupTrim then frame.stoneDockGroupTrim:SetShown(show and gulveig) end
    for _,t in ipairs(styled[frame]) do t:SetShown(show and not gulveig) end
end

local function applyGroupPreference(key, stateKey, active, value)
    local c=C_CVar
    if not c or not c.GetCVar or not c.SetCVar or not StoneDockCharDB or InCombatLockdown() then return end
    local current=c.GetCVar(key)
    if current==nil then return end
    local state=StoneDockCharDB[stateKey]
    local desired
    if active then
        if not state then state={original=current} StoneDockCharDB[stateKey]=state end
        desired=value
        state.applied=desired
    elseif state then
        if current==state.applied then desired=state.original end
        StoneDockCharDB[stateKey]=nil
    end
    if desired and current~=desired then c.SetCVar(key,desired) end
end

function SD:RefreshGroupClassColors(active)
    active = active and self.db.arrangeGroups
    applyGroupPreference("raidFramesDisplayClassColor", "groupClassColorState", active,
        self.db.groupClassColors and "1" or "0")
end

function SD:RefreshGroupIndicators(active)
    active = active and self.db.arrangeGroups
    applyGroupPreference("raidFramesDisplayPowerBars", "groupPowerBarState", active, "1")
    applyGroupPreference("raidFramesDisplayOnlyHealerPowerBars", "groupHealerPowerBarState", active, "0")
    applyGroupPreference("raidFramesDisplayDebuffs", "groupDebuffState", active, "1")
    applyGroupPreference("raidFramesDisplayOnlyDispellableDebuffs", "groupDispelFilterState", active, "0")
end

function SD:RefreshUnitTrim()
    if not self.db or InCombatLockdown() then return end
    local active=self.db.enabled and self:IsOurLayoutActive()
    self:RefreshGroupClassColors(active)
    self:RefreshGroupIndicators(active)
    self:RefreshOrnamentalFrames(active)
    local show=self.db.stoneUnits and active
    local function apply(frame) trim(frame,show) end
    -- Portrait frames have large invisible bounds; edging those bounds made an
    -- unintended rectangle around the player. Trim only compact group frames.
    if CompactPartyFrame then
        for _,frame in ipairs(CompactPartyFrame.memberUnitFrames or {}) do apply(frame) end
    end
    if CompactRaidFrameContainer and CompactRaidFrameContainer.ApplyToFrames then
        CompactRaidFrameContainer:ApplyToFrames("all",apply)
    end
    for frame in pairs(styled) do apply(frame) end
end

function SD:ApplyUnitLayout()
    local busy,why = self:IsBusy()
    if busy then SD.Print(why) return false end
    if not self:IsOurLayoutActive() then SD.Print("Activate the StoneDock layout first.") return false end
    local full,err=self:GetFullLayouts()
    if not full then SD.Print(err) return false end
    local layout=full.layouts[full.activeLayout]
    local H,U,S = self.UnitLayoutHelpers,Enum.EditModeUnitFrameSystemIndices,Enum.EditModeUnitFrameSetting
    local g=self:GetGeometry()
    for _,index in ipairs({U.Player,U.Target,U.Focus}) do
        H.setting(H.find(layout,Enum.EditModeSystem.UnitFrame,index),S.FrameSize,self.db.unitSize*g.scale)
    end
    for _,index in ipairs({U.Party,U.Raid}) do
        local info=H.find(layout,Enum.EditModeSystem.UnitFrame,index)
        H.setting(info,S.FrameWidth,self.db.groupWidth)
        H.setting(info,S.FrameHeight,self.db.groupHeight)
        H.setting(info,S.FrameSize,100*g.scale)
        if index==U.Party then
            H.setting(info,S.UseRaidStylePartyFrames,1)
            H.setting(info,S.UseHorizontalGroups,1)
        else
            local types=Enum.RaidGroupDisplayType
            if types then H.setting(info,S.RaidGroupDisplayType,types.SeparateGroupsVertical) end
        end
        if index==U.Party then
            self:ConfigureNativeParty(info,g)
        else
            local pos=g.raid
            H.anchor(info,"TOPLEFT","BOTTOMLEFT",(pos.x+self.db.groupOffsetX)*g.scale,(pos.y+self.db.groupOffsetY)*g.scale)
        end
    end
    local ok=self:Run("Apply unit layout",function() self:SaveAndRefreshLayout(full,full.activeLayout) end)
    if not ok then return false end
    self:RefreshUnitTrim()
    self:QueueRaidSplit()
    SD.Print("Unit sizes and group layout applied. Use Blizzard Edit Mode to move individual unit frames.")
    return true
end

function SD:PreviewRaid(count)
    if self.raidPreview then self.raidPreview:Hide() self.raidPreview=nil end
    if not count or count==0 then return end
    if InCombatLockdown() then SD.Print("Finish combat before opening the preview.") return end
    count=math.floor(SD.Clamp(count,5,40)/5)*5
    local g=self:GetGeometry()
    local f=self.raidPreviewPool or CreateFrame("Frame",nil,UIParent)
    self.raidPreviewPool=f f.cards=f.cards or {}
    for _,card in ipairs(f.cards)do card:Hide()end
    self.raidPreview=f f.count=count f:ClearAllPoints()f:Show()
    f:SetFrameStrata("HIGH") f:SetScale(g.scale)
    f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",0,0)
    f:SetSize(1920,g.screenHeight)
    local fit=self:GetRaidGrooveScale()
    local w,h=self.db.groupWidth*fit,self.db.groupHeight*fit
    local positions=self:GetRaidSplit(count)
    local title=f.title or f:CreateFontString(nil,"OVERLAY","GameFontNormal")f.title=title
    title:ClearAllPoints()
    title:SetPoint("BOTTOM",f,"BOTTOM",0,positions[1].y+12)
    title:SetText("RAID PREVIEW: "..count.." players - /stonedock raidpreview 0 to close")
    local colors={{0.78,0.61,0.43},{0.96,0.55,0.73},{0.25,0.78,0.92},{0.33,0.72,0.3},{0.6,0.44,0.85}}
    for i=1,count do
        local card=f.cards[i]or CreateFrame("Frame",nil,f,"BackdropTemplate")f.cards[i]=card card:ClearAllPoints()card:Show()
        local pos=positions[math.ceil(i/5)]
        w,h=pos.w,pos.h
        card:SetSize(w,h) card:SetPoint("TOPLEFT",f,"BOTTOMLEFT",pos.x+((i-1)%5)*(w+pos.gap),pos.y)
        card:SetBackdrop({bgFile="Interface\\AddOns\\StoneDock\\Media\\Stone.tga",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=2})
        card:SetBackdropBorderColor(.3,.36,.4,1)
        local c=colors[(i-1)%5+1]
        local bar=card.bar or card:CreateTexture(nil,"ARTWORK")card.bar=bar bar:SetPoint("TOPLEFT",2,-2) bar:SetSize((w-4)*(.55+(i%5)*.09),h-4) bar:SetColorTexture(c[1],c[2],c[3],.8)
        local name=card.nameLabel or card:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")card.nameLabel=name name:SetPoint("CENTER") name:SetText(({"Tank","Healer","Damage","Damage","Healer"})[(i-1)%5+1].." "..i)
    end
end

function SD:ToggleUnitOptions()
    if not self.unitOptions then
        local H=self.ControlHelpers
        local f=CreateFrame("Frame","StoneDockUnitOptions",UIParent,"BackdropTemplate") self.unitOptions=f
        f:SetSize(670,620) f:SetPoint("CENTER") f:SetFrameStrata("DIALOG")
        f:SetBackdrop({bgFile="Interface\\AddOns\\StoneDock\\Media\\Stone.tga",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=256,edgeSize=14})
        H.text(f,"UNIT & RAID FRAMES",21,26,-25,610)
        H.text(f,"Native health, auras and clicks. Sizes apply when you press Apply.",12,26,-64,610)
        local close=CreateFrame("Button",nil,f,"UIPanelCloseButton") f.closeButton=close close:SetPoint("TOPRIGHT",-6,-6) close:SetScript("OnClick",function() f:Hide() end)
        f.sliders={
            H.slider(f,"Player / target / focus size (%)","unitSize",100,200,5,26,-105),
            H.slider(f,"Row width (%)","groupRowWidth",70,100,1,350,-105),
            H.slider(f,"Preferred row height","groupHeight",24,72,2,350,-175),
            H.slider(f,"Group horizontal position","groupOffsetX",-350,700,5,26,-245),
            H.slider(f,"Group vertical position","groupOffsetY",-100,500,5,350,-245),
        }
        local check=H.check(f,"Stone trim around native unit frames","stoneUnits",26,-180)
        check:SetScript("OnClick",function(b) SD.db.stoneUnits=b:GetChecked()==true SD:RefreshUnitTrim() end)
        f.trimCheck=check
        local split=H.check(f,"Split raid groups around the map","splitRaid",26,-211)
        split:SetScript("OnClick",function(b)
            if InCombatLockdown() then b:SetChecked(SD.db.splitRaid) SD.Print("Finish combat first.") return end
            SD.db.splitRaid=b:GetChecked()==true
            if CompactRaidFrameContainer and CompactRaidFrameContainer.TryUpdate then CompactRaidFrameContainer:TryUpdate() end
            SD:QueueRaidSplit()
        end)
        f.splitCheck=split
        f.classColors=H.check(f,"Class colors for party and raid health bars","groupClassColors",26,-294)
        f.classColors:SetScript("OnClick",function(b)
            SD.db.groupClassColors=b:GetChecked()==true
            SD:RefreshGroupClassColors(SD.db.enabled and SD:IsOurLayoutActive())
        end)
        H.button(f,"Apply unit & group layout",26,-330,285,function() SD:ApplyUnitLayout() end)
        H.button(f,"Blizzard Edit Mode",350,-330,285,function() f:Hide() SD:OpenEditMode() end)
        for i,count in ipairs({10,20,25,40}) do
            H.button(f,"Preview "..count,26+(i-1)*157,-380,145,function() SD:PreviewRaid(count) SD:CloseSettings() end)
        end
        H.button(f,"Preview party / close",26,-430,285,function() if SD.raidPreview then SD:PreviewRaid(0) else SD:PreviewRaid(5) SD:CloseSettings() end end)
        H.button(f,"Attach player buffs / debuffs",26,-480,285,function() SD:ApplySessionLayout(true) end)
        H.button(f,"Choose buff food",350,-480,285,function() SD:ShowItemPicker("bufffood","Buff food for current spec") end)
        H.button(f,"Back to appearance",350,-430,285,function() f:Hide() SD:ToggleOptions(true) end)
        H.text(f,"Preview cards are samples, disappear in combat, and do not accept healing clicks. Real group frames appear when you join a group.",12,26,-540,610)
        f:SetScript("OnShow",function() SD:RefreshFading(true) end)
        f:SetScript("OnHide",function() SD:RefreshFading() end)
        f:Hide()
    end
    local f=self.unitOptions
    f.refreshing=true
    f.classColors:SetChecked(self.db.groupClassColors)
    for _,s in ipairs(f.sliders) do s:SetValue(self.db[s.dbKey]) end
    f.splitCheck:SetChecked(self.db.splitRaid)
    f.trimCheck:SetChecked(self.db.stoneUnits) f.refreshing=nil
    f:SetShown(not f:IsShown())
end

SD:On("PLAYER_LOGIN",function() SD:RefreshUnitTrim() end)
SD:On("GROUP_ROSTER_UPDATE",function() SD:RefreshUnitTrim() end)
SD:On("PLAYER_REGEN_ENABLED",function() SD:RefreshUnitTrim() end)
SD:On("EDIT_MODE_LAYOUTS_UPDATED",function() SD:RefreshUnitTrim() end)
SD:On("PLAYER_REGEN_DISABLED",function() SD:PreviewRaid(0) end)

SD:On("PLAYER_ENTERING_WORLD",function() SD:RefreshUnitTrim() end)


-- Each five-person group is a horizontal row. Both banks fill their well.
function SD:GetGroupRows(count,geometry)
    local g=geometry or self:GetGeometry()
    local groups=math.ceil(SD.Clamp(count,1,40)/5)
    local left=math.ceil(groups/2)
    local rows=math.max(left,groups-left)
    -- Leave room for the native tracking frame's gold trim and the compact
    -- unit frames' bottom aura/power strip, not just their nominal rectangles.
    local bottom=math.max(g.leftWell.y+g.leftWell.h,g.rightWell.y+g.rightWell.h)+math.max(22, 20/g.scale)+self.db.groupOffsetY
    if g.variant=="tofu" then
        return self:GetTofuGroupRows(groups,g)
    end
    local chatBounds
    if g.variant=="gulveig" then
        chatBounds=self:GetGulveigChatBounds(g)
        -- Chat tabs/art, then the item row, then a separate group row.
        bottom=math.max(bottom,chatBounds.y+chatBounds.h+44+24*.85+16+self.db.groupOffsetY)
    end
    local available=chatBounds and (rows*self.db.groupHeight+(rows-1)*4)
        or math.max(40,g.left.y+g.left.h+12-bottom)
    local gap=4
    local height=math.max(16,math.min(self.db.groupHeight,math.floor((available-(rows-1)*gap)/rows)))
    local result={}
    for i=1,groups do
        local isLeft=i<=left
        local well=isLeft and g.leftWell or g.rightWell
        if isLeft and chatBounds then well={x=chatBounds.x-22,w=chatBounds.w+44} end
        local row=isLeft and i or i-left
        local rowWidth=(well.w-12)*self.db.groupRowWidth/100
        local width=(rowWidth-4*gap)/5
        result[i]={x=well.x+(well.w-rowWidth)/2+self.db.groupOffsetX,y=bottom+(rows-row+1)*height+(rows-row)*gap,
            w=width,h=height,gap=gap,side=isLeft and "left" or "right"}
    end
    return result
end
function SD:GetRaidSplit(count) return self:GetGroupRows(count) end
function SD:GetRaidGrooveScale() return 1 end

-- PartyFrame owns CompactPartyFrame through Blizzard's layout system. Its
-- persisted anchor must agree with our child placement before combat starts.
function SD:ConfigureNativeParty(info,g)
    if not info or not self.db.arrangeGroups then return end
    g=g or self:GetGeometry()
    local pos=self:GetGroupRows(5,g)[1]
    local H,S=self.UnitLayoutHelpers,Enum.EditModeUnitFrameSetting
    H.anchor(info,"TOPLEFT","BOTTOMLEFT",pos.x*g.scale,pos.y*g.scale)
    H.setting(info,S.UseRaidStylePartyFrames,1)
    H.setting(info,S.UseHorizontalGroups,1)
    H.setting(info,S.ShowPartyFrameBackground,0)
    H.setting(info,S.FrameWidth,pos.w)
    H.setting(info,S.FrameHeight,pos.h)
    H.setting(info,S.FrameSize,100*g.scale)
end

local nativeGroupScales=setmetatable({}, {__mode="k"})
local function near(current, desired)
    return (not issecretvalue or not issecretvalue(current))
        and type(current)=="number" and math.abs(current-desired)<0.01
end

local function seatPoint(frame, relative, relativePoint, x, y)
    local point, anchor, anchorPoint, oldX, oldY=frame:GetPoint()
    if frame:GetNumPoints()==1 and point=="TOPLEFT" and anchor==relative
        and anchorPoint==relativePoint and near(oldX,x) and near(oldY,y) then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT",relative,relativePoint,x,y)
end

local function seat(frame,pos,g,keepNativeCells)
    if not frame then return end
    if keepNativeCells then
        -- Edit Mode already supplies the cell sizes and horizontal layout.
        -- Follow chat without touching the native layout or resizing its children.
        local factor=g.scale*UIParent:GetEffectiveScale()/frame:GetEffectiveScale()
        seatPoint(frame,UIParent,"BOTTOMLEFT",pos.x*factor,pos.y*factor)
        return
    end
    if not nativeGroupScales[frame] then nativeGroupScales[frame]=frame:GetScale() end
    local parent=frame:GetParent() or UIParent
    local scale=g.scale*UIParent:GetEffectiveScale()/parent:GetEffectiveScale()
    if not near(frame:GetScale(),scale) then frame:SetScale(scale) end
    seatPoint(frame,UIParent,"BOTTOMLEFT",pos.x,pos.y)
    local width=5*pos.w+4*pos.gap
    if not near(frame:GetWidth(),width) or not near(frame:GetHeight(),pos.h) then frame:SetSize(width,pos.h) end
    if frame.title then frame.title:SetAlpha(0) end
    for i,member in ipairs(frame.memberUnitFrames or {}) do
        seatPoint(member,frame,"TOPLEFT",(i-1)*(pos.w+pos.gap),0)
        if not near(member:GetWidth(),pos.w) or not near(member:GetHeight(),pos.h) then member:SetSize(pos.w,pos.h) end
    end
end

function SD:SplitNativeRaid()
    if not self.db or InCombatLockdown() then return end
    local active=self.db.enabled and self.db.arrangeGroups and self:IsOurLayoutActive()
    if self.editing or (EditModeManagerFrame and EditModeManagerFrame:IsShown()) then return end
    if not active then
        for frame,scale in pairs(nativeGroupScales) do
            if not near(frame:GetScale(),scale) then frame:SetScale(scale) end
            nativeGroupScales[frame]=nil
        end
        return
    end
    local g=self:GetGeometry()
    -- Party uses the same native cells in one evenly spaced five-wide row.
    if CompactPartyFrame and CompactPartyFrame:IsShown() then seat(CompactPartyFrame,self:GetGroupRows(5,g)[1],g,g.variant=="gulveig") end
    if not self.db.splitRaid then return end
    local container=CompactRaidFrameContainer
    if not container or not container.GetGroupMode or container:GetGroupMode()~="discrete" then return end
    local groups={}
    for i=1,8 do
        local frame=_G["CompactRaidGroup"..i]
        if frame and frame:IsShown() then groups[#groups+1]=frame end
    end
    if #groups==0 then return end
    local positions=self:GetGroupRows(#groups*5)
    for i,frame in ipairs(groups) do seat(frame,positions[i],g) end
end

function SD:QueueRaidSplit()
    if self.raidSplitPending or InCombatLockdown() then return end
    self.raidSplitPending=true
    C_Timer.After(0,function()
        SD:Run("Split raid frames",function() SD:SplitNativeRaid() end)
        SD.raidSplitPending=nil
    end)
end

function SD:InstallRaidSplitHook()
    if hooksecurefunc and PartyFrame and PartyFrame.Layout and not self.partyParentLayoutHooked then
        self.partyParentLayoutHooked=true
        hooksecurefunc(PartyFrame,"Layout",function() SD:QueueRaidSplit() end)
    end
    if hooksecurefunc and not self.groupLayoutHooked and CompactRaidGroup_UpdateLayout then
        self.groupLayoutHooked=true
        hooksecurefunc("CompactRaidGroup_UpdateLayout",function() SD:QueueRaidSplit() end)
    end
    if hooksecurefunc and CompactPartyFrame and CompactPartyFrame.UpdateLayout and not self.partyLayoutHooked then
        self.partyLayoutHooked=true
        hooksecurefunc(CompactPartyFrame,"UpdateLayout",function() SD:QueueRaidSplit() end)
    end
    local container=CompactRaidFrameContainer
    if container and container.LayoutFrames and not self.raidSplitHooked and hooksecurefunc then
        self.raidSplitHooked=true
        hooksecurefunc(container,"LayoutFrames",function() SD:QueueRaidSplit() end)
    end
end
SD:On("PLAYER_LOGIN",function() SD:InstallRaidSplitHook() SD:QueueRaidSplit() end)
SD:On("ADDON_LOADED",function() if SD.db then SD:InstallRaidSplitHook() SD:QueueRaidSplit() end end)
SD:On("GROUP_ROSTER_UPDATE",function() SD:QueueRaidSplit() end)
SD:On("PLAYER_REGEN_ENABLED",function() SD:QueueRaidSplit() end)
SD:On("EDIT_MODE_LAYOUTS_UPDATED",function() SD:QueueRaidSplit() end)

