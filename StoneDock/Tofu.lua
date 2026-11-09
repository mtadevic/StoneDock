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
    local leftMeter=box(520,5,215,157)
    local rightMeter=box(1192,5,212,157)
    return {
        variant="tofu",revision=1,width=width,height=height,scale=scale,density=rise,screenHeight=screenHeight,
        left=box(0,0,517,332),right=box(1408,0,512,310),base=box(0,0,1920,3),
        map={x=1618,y=screenHeight-324*rise,w=286,h=286*rise},
        leftWell=leftMeter,rightWell=rightMeter,
        meters={leftMeter,rightMeter},
        chat=box(28,30,475,274),menuDrawer=box(831,1,258,34),bagDrawer=box(1640,10,264,40),
        itemWell=box(1178,173,250,24),utilityY=173*rise,
        trackingWell=box(423,0,1074,25),
        auxLeft=box(520,160,130,69),auxRight=box(1408,205,240,51),
        cast={x=0,y=(191+dy)*rise},
        player={x=651,y=209*rise},target={x=1272,y=209*rise},
        party={x=620,y=395*rise},raid={x=620,y=466*rise},
        bars={
            bar(1,960,160,5,1,46),
            bar(2,960,86,10,2,46),
            bar(3,781,91,8,4,38),
            bar(4,1146,91,8,4,38),
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
        anchor(E.ActionBar,11,"BOTTOMLEFT","BOTTOMLEFT",g.auxLeft.x+12,g.auxLeft.y+g.auxLeft.h-18*g.density)
        for index=12,13 do
            anchor(E.ActionBar,index,"BOTTOMLEFT","BOTTOMLEFT",g.auxRight.x+12,g.auxRight.y+g.auxRight.h-18*g.density)
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
        H.setting(H.find(layout,E.CastBar),Enum.EditModeCastBarSetting.BarSize,75*s)
    end
end

local function plate(parent,alpha)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:EnableMouse(false)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize=10,insets={left=3,right=3,top=3,bottom=3}})
    f:SetBackdropColor(.035,.032,.030,alpha or .97)
    f:SetBackdropBorderColor(.62,.57,.50,1)
    -- A dark inset and a narrow highlight read as an engraved metal edge.
    local rim=f:CreateTexture(nil,"BORDER",nil,1)
    rim:SetColorTexture(.48,.43,.36,.7)
    rim:SetPoint("TOPLEFT",f,"TOPLEFT",8,-4)
    rim:SetPoint("TOPRIGHT",f,"TOPRIGHT",-8,-4)
    rim:SetHeight(1)
    return f
end

function SD:RefreshTofuArt(g)
    local show=g.variant=="tofu" and self.db.enabled and (self:IsOurLayoutActive() or self.db.showGuides or self.editing)
    if not self.tofuArt then
        if not show then return end
        local art=CreateFrame("Frame",nil,self.canvas)
        art:SetAllPoints()
        art:EnableMouse(false)
        art:SetFrameStrata("BACKGROUND")
        art.plates={}
        for i=1,10 do art.plates[i]=plate(art,i==1 and 0 or .95) end
        self.tofuArt=art
    end
    local art=self.tofuArt
    art:SetShown(show)
    if not show then return end
    local r=g.density
    local center=g.bars[1].x
    local zoom=self.db.barWidth/100
    local shapes={
        {x=0,y=0,w=1920,h=g.screenHeight},
        g.left,g.right,g.meters[1],g.meters[2],
        {x=g.bars[3].x-49*zoom,y=0,w=98*zoom,h=(183+self.db.barOffsetY)*r},
        {x=g.bars[4].x-49*zoom,y=0,w=98*zoom,h=(186+self.db.barOffsetY)*r},
        {x=center-130*zoom,y=0,w=260*zoom,h=226*r},
        {x=520,y=162*r,w=128,h=59*r},
        {x=1278,y=162*r,w=130,h=59*r},
    }
    shapes[8].h=math.max(35*r,(226+self.db.barOffsetY)*r)
    for i,rect in ipairs(shapes) do
        local f=art.plates[i]
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
            trim=plate(frame,.9)
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
