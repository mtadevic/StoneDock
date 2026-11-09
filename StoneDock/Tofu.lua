local _, SD = ...

function SD:GetTofuGeometry(width,height,rise)
    local scale=width/1920
    local screenHeight=height/scale
    local dx=self.db.barOffsetX
    local dy=self.db.barOffsetY
    local zoom=self.db.barWidth/100
    local function box(x,y,w,h) return {x=x,y=y*rise,w=w,h=h*rise} end
    local function bar(index,x,y,icons,rows,size)
        return {index=index,x=960+(x-960)*zoom+dx,y=(y+dy)*rise,icons=icons,rows=rows,iconSize=size*zoom*rise}
    end
    local physicalHeight
    if GetPhysicalScreenSize then local _; _,physicalHeight=GetPhysicalScreenSize() end
    local pixel=physicalHeight and screenHeight/physicalHeight or 1
    local function snap(value) return math.floor(value/pixel+.5)*pixel end
    local center=960+snap(dx)
    local function pair(inner,w,y,h)
        inner,w=snap(inner),snap(w)
        return box(center-inner-w,y,w,h),box(center+inner,y,w,h)
    end
    local centerHalf=snap(130*zoom)
    local meterBase=161
    local leftBank,rightBank=pair(centerHalf,98*zoom,0,181+dy)
    local meterInner=centerHalf+leftBank.w
    local leftMeter,rightMeter=pair(meterInner,214,4,157)
    local outerInner=meterInner+leftMeter.w
    local left=box(0,0,center-outerInner,326)
    local right=box(center+outerInner,0,1920-center-outerInner,326)
    local leftMeterPlate,rightMeterPlate=pair(meterInner,214,0,meterBase)
    local leftTray,rightTray=pair(meterInner,214,meterBase,60)
    return {
        variant="tofu",revision=3,width=width,height=height,scale=scale,density=rise,screenHeight=screenHeight,
        left=left,right=right,base=box(0,0,1920,3),
        map={x=1627,y=screenHeight-310*rise,w=264,h=264*rise},
        leftWell=leftMeter,rightWell=rightMeter,meters={leftMeter,rightMeter},
        silhouette={left,right,leftMeterPlate,rightMeterPlate,leftBank,rightBank,box(center-centerHalf,0,2*centerHalf,224+dy),leftTray,rightTray},
        chat=box(28,30,left.w-42,270),menuDrawer=box(center-129,1,258,34),bagDrawer=box(1640,10,264,40),
        itemWell=box(rightTray.x+5+self.db.tofuItemOffsetX,181+self.db.tofuItemOffsetY,rightTray.w-10,24),utilityY=181*rise,
        trackingWell=box(423,0,1074,25),
        auxLeft=leftTray,auxRight=rightTray,auxTopInset=9,
        cast={x=dx,y=(194+dy)*rise},
        player={x=center-308,y=(235+dy)*rise},target={x=center+308,y=(235+dy)*rise},
        party={x=620,y=395*rise},raid={x=620,y=466*rise},
        bars={
            bar(1,960,160,5,1,46),
            bar(2,960,86,10,2,46),
            bar(3,960-(center-leftBank.x-leftBank.w/2)/zoom,91,8,4,38),
            bar(4,960+(rightBank.x+rightBank.w/2-center)/zoom,91,8,4,38),
        },
    }
end

function SD:GetTofuGroupRows(groups,g)
    local gap=4
    local width=(676*self.db.groupRowWidth/100-4*gap)/5
    local height=self.db.groupHeight
    local result={}
    for i=1,groups do
        result[i]={x=960-(5*width+4*gap)/2+self.db.groupOffsetX,
            y=g.party.y+self.db.groupOffsetY+(groups-i)*(height+gap),
            w=width,h=height,gap=gap,side="left"}
    end
    return result
end

function SD:FinishTofuLayout(layout,g,dashboardOnly)
    local H,E=self.UnitLayoutHelpers,Enum.EditModeSystem
    local s=g.scale
    local function anchor(system,index,point,relative,x,y)
        H.anchor(H.find(layout,system,index),point,relative,x*s,y*s)
    end
    local map=H.find(layout,E.Minimap)
    H.setting(map,Enum.EditModeMinimapSetting.HeaderUnderneath,0)
    anchor(E.Minimap,nil,"CENTER","BOTTOMLEFT",g.map.x+g.map.w/2,g.map.y+g.map.h/2)
    if self.db.arrangeUtility then
        anchor(E.StatusTrackingBar,1,"TOP","TOP",0,-12*g.density)
        anchor(E.StatusTrackingBar,2,"TOP","TOP",0,-28*g.density)
        anchor(E.ActionBar,11,"TOPRIGHT","BOTTOMLEFT",g.auxLeft.x+g.auxLeft.w-12,g.auxLeft.y+g.auxLeft.h-g.auxTopInset*g.density)
        for index=12,13 do
            anchor(E.ActionBar,index,"TOPLEFT","BOTTOMLEFT",g.auxRight.x+12,g.auxRight.y+g.auxRight.h-g.auxTopInset*g.density)
        end
        if not dashboardOnly then anchor(E.ObjectiveTracker,nil,"TOPRIGHT","TOPRIGHT",-16,-362*g.density) end
    end
    if not dashboardOnly and self.db.arrangeUnits then
        local U,S=Enum.EditModeUnitFrameSystemIndices,Enum.EditModeUnitFrameSetting
        for _,index in ipairs({U.Player,U.Target,U.Focus,U.Pet}) do
            H.setting(H.find(layout,E.UnitFrame,index),S.FrameSize,72*s)
        end
        anchor(E.UnitFrame,U.Pet,"BOTTOMRIGHT","BOTTOMLEFT",g.player.x-8,g.player.y)
    end
    if not dashboardOnly then
        anchor(E.CastBar,nil,"BOTTOM","BOTTOM",g.cast.x,g.cast.y)
        H.setting(H.find(layout,E.CastBar),Enum.EditModeCastBarSetting.BarSize,75*s)
    end
end

local function plate(parent,alpha)
    local f=CreateFrame("Frame",nil,parent)
    f:EnableMouse(false)
    local fill=f:CreateTexture(nil,"BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(.037,.040,.044,alpha)
    for i=1,3 do
        local inset=(i-1)*1.5
        local shade=({.075,.34,.13})[i]
        for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
            local edge=f:CreateTexture(nil,"BORDER")
            edge:SetColorTexture(shade,shade*1.04,shade*1.09,1)
            if side=="TOP" or side=="BOTTOM" then
                local y=side=="TOP" and -inset or inset
                edge:SetPoint(side.."LEFT",f,side.."LEFT",inset,y)
                edge:SetPoint(side.."RIGHT",f,side.."RIGHT",-inset,y)
                edge:SetHeight(1.5)
            else
                local x=side=="LEFT" and inset or -inset
                edge:SetPoint("TOP"..side,f,"TOP"..side,x,-inset)
                edge:SetPoint("BOTTOM"..side,f,"BOTTOM"..side,x,inset)
                edge:SetWidth(1.5)
            end
        end
    end
    for _,side in ipairs({"TOPLEFT","TOPRIGHT","BOTTOMLEFT","BOTTOMRIGHT"}) do
        local right=side:find("RIGHT",1,true)~=nil
        local bottom=side:find("BOTTOM",1,true)~=nil
        local corner=f:CreateTexture(nil,"OVERLAY")
        corner:SetTexture("Interface\\AddOns\\StoneDock\\Media\\TofuCorner.tga")
        corner:SetTexCoord(right and 1 or 0,right and 0 or 1,bottom and 1 or 0,bottom and 0 or 1)
        corner:SetPoint(side)
        corner:SetSize(18,18)
    end
    return f
end

function SD:RefreshTofuArt(g)
    self:FitTofuTopRow()
    local show=g.variant=="tofu" and self.db.enabled and (self:IsOurLayoutActive() or self.db.showGuides or self.editing)
    if not self.tofuArt then
        if not show then return end
        local art=CreateFrame("Frame",nil,self.canvas)
        art:SetAllPoints()
        art:EnableMouse(false)
        art:SetFrameStrata("BACKGROUND")
        art.plates={}
        for i=1,10 do art.plates[i]=plate(art,i==1 and 0 or 1) end
        self.tofuArt=art
    end
    local art=self.tofuArt
    art:SetShown(show)
    if not show then return end
    art.plates[1]:SetPoint("BOTTOMLEFT",art,"BOTTOMLEFT",0,0)
    art.plates[1]:SetSize(1920,g.screenHeight)
    for i,rect in ipairs(g.silhouette) do
        local f=art.plates[i+1]
        f:SetPoint("BOTTOMLEFT",art,"BOTTOMLEFT",rect.x,rect.y)
        f:SetSize(rect.w,rect.h)
    end
end

local unitPlates=setmetatable({}, {__mode="k"})
function SD:RefreshTofuUnitArt(active,barRegion,rect)
    local show=active and self.layoutName=="Tofu Bar" and self.db.stoneUnits
    for _,frame in pairs({PlayerFrame,TargetFrame,FocusFrame,PetFrame,PlayerCastingBarFrame,CastingBarFrame,
        PetCastingBarFrame,TargetFrame and (TargetFrame.spellbar or TargetFrame.CastBar),
        FocusFrame and (FocusFrame.spellbar or FocusFrame.CastBar)}) do
        local trim=unitPlates[frame]
        if show and not trim then
            trim=plate(frame,1)
            trim:SetFrameLevel(math.max(0,frame:GetFrameLevel()-1))
            unitPlates[frame]=trim
        end
        if show then
            local container=frame.PlayerFrameContainer or frame.TargetFrameContainer
            local portrait=frame.portrait or frame.Portrait or (container and container.Portrait)
            local bar=barRegion(frame)
            local bx,by,bw,bh=rect(bar,frame)
            local px,py,pw,ph=rect(portrait,frame)
            trim:ClearAllPoints()
            if bx and px then
                trim:SetPoint("BOTTOMLEFT",bar,"BOTTOMLEFT",math.min(0,px-bx)-3,math.min(-bh*.65,py-by)-2)
                trim:SetPoint("TOPRIGHT",bar,"TOPRIGHT",math.max(0,px+pw-bx-bw)+3,math.max(bh*.85,py+ph-by-bh)+2)
            else
                trim:SetPoint("TOPLEFT",frame,"TOPLEFT",-3,3)
                trim:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",3,-3)
            end
        end
        if trim then trim:SetShown(not not show) end
    end
end

-- Apply to two explicitly opened Details windows only when requested.
function SD:DockTofuMeters()
    if self.layoutName~="Tofu Bar" or not self:IsOurLayoutActive() or self:IsBusy() then
        SD.Print("Select Tofu Bar and leave combat and Edit Mode before placing Details windows.")
        return
    end
    local get=Details and (Details.GetWindow or Details.GetInstance)
    local windows={}
    for i=1,2 do
        local window=get and get(Details,i)
        if not window or not window.baseframe or not window.baseframe:IsShown()
            or not window.SetDisplay or not window.SaveMainWindowPosition then
            SD.Print("Open Details windows 1 and 2, then use /stonedock tofumeters.")
            return
        end
        windows[i]=window
    end
    local g=self:GetGeometry()
    for i,window in ipairs(windows) do
        local frame,well=window.baseframe,g.meters[i]
        local scale=frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",(well.x+4)*g.scale/scale,(well.y+3)*g.scale/scale)
        frame:SetSize((well.w-8)*g.scale/scale,(well.h-19*g.density)*g.scale/scale)
        window:SetDisplay(nil,i,1)
        window:SaveMainWindowPosition()
    end
    SD.Print("Details placed: Damage Done on the left, Healing Done on the right.")
end
local function queueTopRow()
    if SD.tofuTopRowQueued then return end
    SD.tofuTopRowQueued=true
    C_Timer.After(0,function()
        SD.tofuTopRowQueued=nil
        SD:FitTofuTopRow()
    end)
end

function SD:FitTofuTopRow()
    local bar=MainActionBar
    if not bar or not bar.UpdateShownButtons or not bar.MarkGridLayoutDirty then return end
    if self:IsBusy() then return end
    local active=self.db.enabled and self.layoutName=="Tofu Bar" and self:IsOurLayoutActive()
    if active and bar.numButtonsShowable and bar.numButtonsShowable>5 then
        self.tofuNativeButtonCount=bar.numButtonsShowable
        bar.numButtonsShowable=5
    elseif not active and self.tofuNativeButtonCount then
        local previous=self.tofuNativeButtonCount
        self.tofuNativeButtonCount=nil
        if bar.numButtonsShowable~=5 then return end
        bar.numButtonsShowable=previous
    else return end
    bar:UpdateShownButtons()
    bar:MarkGridLayoutDirty()
    self:SchedulePrecisionAlignment(false)
end

SD:On("PLAYER_LOGIN",function()
    if hooksecurefunc and MainActionBar and MainActionBar.UpdateSystemSettingNumIcons then
        hooksecurefunc(MainActionBar,"UpdateSystemSettingNumIcons",function()
            if SD.layoutName=="Tofu Bar" then queueTopRow() end
        end)
    end
end)
local function finishTopRow()
    if SD.layoutName=="Tofu Bar" or SD.tofuNativeButtonCount then queueTopRow() end
end
SD:On("PLAYER_REGEN_ENABLED",finishTopRow)
