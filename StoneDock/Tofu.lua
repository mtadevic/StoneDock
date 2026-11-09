local _, SD = ...

function SD:GetTofuGeometry(width,height,rise)
    local scale=width/1920
    local screenHeight=height/scale
    local dx=self.db.barOffsetX
    local dy=self.db.barOffsetY
    local zoom=self.db.barWidth/100
    local function box(x,y,w,h) return {x=x,y=y*rise,w=w,h=h*rise} end
    local function bar(index,x,y,icons,rows,size)
        return {index=index,x=x,y=(y+dy)*rise,icons=icons,rows=rows,iconSize=size*zoom*rise,iconPadding=4}
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
    local leftBank,rightBank=pair(centerHalf,94*zoom,0,179+dy)
    local meterInner=centerHalf+leftBank.w
    local leftMeter,rightMeter=pair(meterInner,214,4,157)
    local outerInner=meterInner+leftMeter.w
    local left=box(0,0,center-outerInner,326)
    local right=box(center+outerInner,0,1920-center-outerInner,326)
    local leftMeterPlate,rightMeterPlate=pair(meterInner,214,0,meterBase)
    local trayWidth=144
    local leftTray,rightTray=pair(outerInner-trayWidth,trayWidth,meterBase,34)
    local utilityIconSize=24*.85
    local utilityY=leftTray.y+(leftTray.h-utilityIconSize)/2
    local centerPlate=box(center-centerHalf,0,2*centerHalf,186+dy)
    return {
        variant="tofu",revision=7,width=width,height=height,scale=scale,density=rise,screenHeight=screenHeight,
        left=left,right=right,base=box(0,0,1920,3),
        map={x=1627,y=screenHeight-310*rise,w=264,h=264*rise},
        leftWell=leftMeter,rightWell=rightMeter,meters={leftMeter,rightMeter},
        silhouette={left,right,leftMeterPlate,rightMeterPlate,leftBank,rightBank,centerPlate,leftTray,rightTray},
        chat=box(28,30,left.w-42,270),menuDrawer=box(center-129,1,258,34),bagDrawer=box(1640,10,264,40),
        itemWell={x=rightTray.x+5+self.db.tofuItemOffsetX,y=utilityY+self.db.tofuItemOffsetY*rise,
            w=rightTray.w-10,h=utilityIconSize},
        utilityY=utilityY,utilityIconSize=utilityIconSize,
        trackingWell=box(423,0,1074,25),
        auxLeft=leftTray,auxRight=rightTray,auxTopInset=(leftTray.h-utilityIconSize)/2,
        auxRightTop=rightTray.y+rightTray.h+26*rise,
        cast={x=center-960,y=centerPlate.h+16*rise},
        player={x=center-308,y=(235+dy)*rise},target={x=center+308,y=(235+dy)*rise},
        party={x=620,y=395*rise},raid={x=620,y=466*rise},
        bars={
            bar(1,center,158,5,1,44),
            bar(2,center,86,10,2,44),
            bar(3,leftBank.x+leftBank.w/2,91,8,4,38),
            bar(4,rightBank.x+rightBank.w/2,91,8,4,38),
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
        local stance=H.find(layout,E.ActionBar,11)
        local nativeSize=ActionButton1 and ActionButton1:GetWidth() or 45
        H.setting(stance,Enum.EditModeActionBarSetting.IconSize,100*g.utilityIconSize*s/nativeSize)
        anchor(E.ActionBar,11,"TOPLEFT","BOTTOMLEFT",g.auxLeft.x+12,g.auxLeft.y+g.auxLeft.h-g.auxTopInset)
        for index=12,13 do
            anchor(E.ActionBar,index,"TOPRIGHT","BOTTOMLEFT",g.auxRight.x+g.auxRight.w-12,g.auxRightTop)
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
    local cast=H.find(layout,E.CastBar)
    anchor(E.CastBar,nil,"BOTTOM","BOTTOM",g.cast.x,g.cast.y)
    H.setting(cast,Enum.EditModeCastBarSetting.LockToPlayerFrame,0)
    H.setting(cast,Enum.EditModeCastBarSetting.BarSize,75*s)
end

local function plate(parent,cornerSize)
    local f=CreateFrame("Frame",nil,parent)
    f:EnableMouse(false)
    local texture="Interface\\AddOns\\StoneDock\\Media\\TofuCorner.tga"
    local center=f:CreateTexture(nil,"BACKGROUND")
    center:SetPoint("TOPLEFT",f,"TOPLEFT",cornerSize,-cornerSize)
    center:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-cornerSize,cornerSize)
    center:SetColorTexture(9/255,10/255,11/255,1)
    -- Stretch the last texel of each corner into a straight edge. Each piece
    -- owns its own area so the canvas opacity is applied exactly once.
    local seam=63.5/64
    for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local edge=f:CreateTexture(nil,"BACKGROUND")
        edge:SetTexture(texture)
        if side=="TOP" or side=="BOTTOM" then
            local top=side=="TOP"
            edge:SetPoint(side.."LEFT",f,side.."LEFT",cornerSize,0)
            edge:SetPoint(side.."RIGHT",f,side.."RIGHT",-cornerSize,0)
            edge:SetHeight(cornerSize)
            edge:SetTexCoord(seam,seam,top and 0 or 1,top and 1 or 0)
        else
            local left=side=="LEFT"
            edge:SetPoint("TOP"..side,f,"TOP"..side,0,-cornerSize)
            edge:SetPoint("BOTTOM"..side,f,"BOTTOM"..side,0,cornerSize)
            edge:SetWidth(cornerSize)
            edge:SetTexCoord(left and 0 or 1,left and 1 or 0,seam,seam)
        end
    end
    for _,side in ipairs({"TOPLEFT","TOPRIGHT","BOTTOMLEFT","BOTTOMRIGHT"}) do
        local right=side:find("RIGHT",1,true)~=nil
        local bottom=side:find("BOTTOM",1,true)~=nil
        local corner=f:CreateTexture(nil,"OVERLAY")
        corner:SetTexture(texture)
        corner:SetTexCoord(right and 1 or 0,right and 0 or 1,bottom and 1 or 0,bottom and 0 or 1)
        corner:SetPoint(side)
        corner:SetSize(cornerSize,cornerSize)
    end
    return f
end

local media="Interface\\AddOns\\StoneDock\\Media\\"
local radius=12
local seam=63.5/64

-- Each column covers a disjoint slice of the silhouette. Draw trim only on
-- the outer contour, so touching trays and banks never draw competing corners.
local function contourColumns(rects)
    local edges, columns={},{}
    for _,r in ipairs(rects) do
        edges[#edges+1]=r.x
        edges[#edges+1]=r.x+r.w
    end
    table.sort(edges)
    for i=1,#edges-1 do
        local x,right=edges[i],edges[i+1]
        if right>x then
            local height=0
            local mid=(x+right)/2
            for _,r in ipairs(rects) do
                if mid>=r.x and mid<r.x+r.w then height=math.max(height,r.y+r.h) end
            end
            local last=columns[#columns]
            if last and last.h==height then last.right=right
            else columns[#columns+1]={x=x,right=right,h=height} end
        end
    end
    return columns
end

local function drawTofuContour(art,rects)
    local fills, trims, corners=0,0,0
    local function place(region,x,y,w,h)
        region:ClearAllPoints()
        region:SetPoint("BOTTOMLEFT",art,"BOTTOMLEFT",x,y)
        region:SetSize(w,h)
        region:Show()
    end
    local function fill(x,y,w,h,corner)
        if w<=0 or h<=0 then return end
        local region
        if corner then region=corner.fill
        else
            fills=fills+1
            region=art.surface[fills]
        end
        if not region then
            region=art:CreateTexture(nil,"BACKGROUND")
            region:SetTexture(media.."WeatheredStone.tga","REPEAT","REPEAT")
            region:SetVertexColor(.25,.26,.29,1)
            if corner then
                corner.fill=region
                corner.mask=art:CreateMaskTexture(nil,"BACKGROUND")
                corner.mask:SetTexture(media.."TofuCorner.tga","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
                region:AddMaskTexture(corner.mask)
            else art.surface[fills]=region end
        end
        place(region,x,y,w,h)
        region:SetTexCoord(x/512,(x+w)/512,-(y+h)/512,-y/512)
    end
    local function trim(x,y,w,h,u1,u2,v1,v2)
        if w<=0 or h<=0 then return end
        trims=trims+1
        local region=art.trim[trims]
        if not region then
            region=art:CreateTexture(nil,"ARTWORK")
            region:SetTexture(media.."TofuTrim.tga")
            art.trim[trims]=region
        end
        place(region,x,y,w,h)
        region:SetTexCoord(u1,u2,v1,v2)
    end
    local function corner(x,y,flipX,flipY)
        corners=corners+1
        local piece=art.corners[corners] or {}
        art.corners[corners]=piece
        local u1,u2=flipX and 1 or 0,flipX and 0 or 1
        local v1,v2=flipY and 1 or 0,flipY and 0 or 1
        fill(x,y,radius,radius,piece)
        place(piece.mask,x,y,radius,radius)
        piece.mask:SetTexCoord(u1,u2,v1,v2)
        trim(x,y,radius,radius,u1,u2,v1,v2)
    end

    local columns=contourColumns(rects)
    for i,c in ipairs(columns) do
        local before=columns[i-1] and columns[i-1].h or 0
        local after=columns[i+1] and columns[i+1].h or 0
        local leftInset=c.h>before and radius or 0
        local rightInset=c.h>after and radius or 0
        local floor=(i==1 or i==#columns) and radius or 0
        local width=c.right-c.x
        fill(c.x,floor,width,c.h-radius-floor)
        fill(c.x+leftInset,c.h-radius,width-leftInset-rightInset,radius)
        trim(c.x+leftInset,c.h-radius,width-leftInset-rightInset,radius,seam,seam,0,1)
        if leftInset>0 then
            corner(c.x,c.h-radius,false,false)
            local y=math.max(before,floor)
            trim(c.x,y,radius,c.h-radius-y,0,1,seam,seam)
        end
        if rightInset>0 then
            corner(c.right-radius,c.h-radius,true,false)
            local y=math.max(after,floor)
            trim(c.right-radius,y,radius,c.h-radius-y,1,0,seam,seam)
        end
        if floor>0 then
            local left=i==1
            fill(c.x+(left and radius or 0),0,width-radius,radius)
            corner(left and c.x or c.right-radius,0,not left,true)
        end
    end
    trim(radius,0,1920-2*radius,radius,seam,seam,1,0)
    for i=fills+1,#art.surface do art.surface[i]:Hide() end
    for i=trims+1,#art.trim do art.trim[i]:Hide() end
    for i=corners+1,#art.corners do art.corners[i].fill:Hide() art.corners[i].mask:Hide() end
end

function SD:RefreshTofuArt(g)
    self:FitTofuTopRow()
    local show=g.variant=="tofu" and self.db.enabled and (self:IsOurLayoutActive() or self.db.showGuides or self.editing)
    if not self.tofuArt then
        if not show then return end
        local art=CreateFrame("Frame",nil,UIParent)
        art:SetPoint("BOTTOM",UIParent,"BOTTOM")
        art:SetFrameLevel(0)
        art:EnableMouse(false)
        art:SetFrameStrata("BACKGROUND")
        art.surface,art.trim,art.corners={},{},{}
        self.tofuArt=art
    end
    local art=self.tofuArt
    art:SetShown(show)
    if not show then return end
    art:SetScale(g.scale)
    art:SetSize(1920,g.screenHeight)
    art:SetAlpha(self.db.opacity*(self.currentUIAlpha or 1))
    local key=table.concat({g.density,self.db.barWidth,self.db.barOffsetX,self.db.barOffsetY,g.width,g.height},"/")
    if art.geometryKey~=key then
        drawTofuContour(art,g.silhouette)
        art.geometryKey=key
    end
end

local unitPlates=setmetatable({}, {__mode="k"})
function SD:RefreshTofuUnitArt(active,barRegion,rect)
    local show=active and self.layoutName=="Tofu Bar" and self.db.stoneUnits
    for _,frame in pairs({FocusFrame,PetFrame,PlayerCastingBarFrame,CastingBarFrame,
        PetCastingBarFrame,TargetFrame and (TargetFrame.spellbar or TargetFrame.CastBar),
        FocusFrame and (FocusFrame.spellbar or FocusFrame.CastBar)}) do
        local trim=unitPlates[frame]
        if show and not trim then
            trim=plate(frame,9)
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
    if bar.UpdateGridLayout then bar:UpdateGridLayout() end
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
