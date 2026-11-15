local _, SD = ...
local surroundWidth, surroundHeight = 1782, 343
local artScale = 1920/surroundWidth
SD.tofuGeometryRevision = 14
SD.tofuUnitAnchorRevision = 2

function SD:PlaceTofuUnitAnchors(layout,g)
    local H,E,U=self.UnitLayoutHelpers,Enum.EditModeSystem,Enum.EditModeUnitFrameSystemIndices
    local function place(index,point,x,y)
        H.anchor(H.find(layout,E.UnitFrame,index),point,"BOTTOMLEFT",x*g.scale,y*g.scale)
    end
    place(U.Player,"BOTTOMLEFT",g.player.x,g.player.y)
    place(U.Target,"BOTTOMRIGHT",g.target.x,g.target.y)
    place(U.Focus,"BOTTOMRIGHT",g.focus.x,g.focus.y)
    if U.Pet then place(U.Pet,"BOTTOMRIGHT",g.pet.x,g.pet.y) end
    if U.Boss then
        H.anchor(H.find(layout,E.UnitFrame,U.Boss),"TOPRIGHT","TOPRIGHT",-260*g.scale,-316*g.density*g.scale)
    end
end

function SD:GetTofuGeometry(width,height,rise)
    local scale=width/1920
    local screenHeight=height/scale
    local dx=self.db.barOffsetX
    local dy=self.db.barOffsetY
    local zoom=self.db.barWidth/100
    local function box(x,y,w,h) return {x=x,y=y*rise,w=w,h=h*rise} end
    local function artBox(x,y,w,h) return box(x*artScale,y*artScale,w*artScale,h*artScale) end
    local function bar(index,x,y,icons,rows,size)
        return {index=index,x=x*artScale+dx,y=(y*artScale+dy)*rise,
            icons=icons,rows=rows,iconSize=size*artScale*zoom*rise,iconPadding=4}
    end
    local center=960+dx
    local left,right=artBox(0,0,480,313),artBox(1302,0,480,313)
    local leftMeter,rightMeter=artBox(488,7,182,141),artBox(1112,7,182,141)
    local leftTray,rightTray=artBox(478,154,170,40),artBox(1134,154,170,40)
    local utilityIconSize=24*.85*rise
    local utilityY=leftTray.y+(leftTray.h-utilityIconSize)/2
    return {
        variant="tofu",revision=self.tofuGeometryRevision,width=width,height=height,scale=scale,density=rise,screenHeight=screenHeight,
        left=left,right=right,base=box(0,0,1920,3),
        map={x=1627,y=screenHeight-310*rise,w=264,h=264*rise},
        leftWell=leftMeter,rightWell=rightMeter,meters={leftMeter,rightMeter},
        chat=box(28,30,left.w-42,270),menuDrawer=artBox(801,3,180,40),bagDrawer=box(1640,10,264,40),
        itemWell={x=rightTray.x+22+self.db.tofuItemOffsetX,y=utilityY+self.db.tofuItemOffsetY*rise,
            w=rightTray.w-44,h=utilityIconSize},
        utilityY=utilityY,utilityIconSize=utilityIconSize,
        trackingWell=box(423,0,1074,25),
        auxLeft=leftTray,auxRight=rightTray,auxTopInset=(leftTray.h-utilityIconSize)/2,
        auxRightTop=rightTray.y+rightTray.h+26*rise,
        cast={x=center-960,y=(199+dy)*rise},
        player={x=602,y=298*rise},target={x=1316,y=298*rise},
        focus={x=1410,y=383*rise},pet={x=778,y=258*rise},
        party={x=24,y=428*rise},raid={x=24,y=428*rise},
        bars={
            bar(1,891,154,5,1,39),
            bar(2,891,87,10,2,39),
            bar(3,723,92,8,4,27),
            bar(4,1059,92,8,4,27),
        },
    }
end

function SD:GetTofuGroupRows(groups,g)
    local gap=4
    local width=(474*self.db.groupRowWidth/100-4*gap)/5
    local height=self.db.groupHeight
    local result={}
    for i=1,groups do
        result[i]={x=g.party.x+self.db.groupOffsetX,
            y=g.party.y+self.db.groupOffsetY+(i-1)*(height+gap),
            w=width,h=height,gap=gap,side="left"}
    end
    return result
end

function SD:PlaceTofuRaidAnchor(layout,g)
    if not self.db.arrangeGroups then return end
    local H=self.UnitLayoutHelpers
    local raid=H.find(layout,Enum.EditModeSystem.UnitFrame,Enum.EditModeUnitFrameSystemIndices.Raid)
    local row=self:GetTofuGroupRows(1,g)[1]
    H.anchor(raid,"TOPLEFT","BOTTOMLEFT",row.x*g.scale,row.y*g.scale)
end

function SD:FinishTofuLayout(layout,g,dashboardOnly,upgradeUnits)
    self:PlaceTofuRaidAnchor(layout,g)
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
        H.setting(stance,Enum.EditModeActionBarSetting.IconSize,100*g.utilityIconSize*s/30)
        anchor(E.ActionBar,11,"TOPLEFT","BOTTOMLEFT",g.auxLeft.x+24,g.auxLeft.y+g.auxLeft.h-g.auxTopInset)
        for index=12,13 do
            anchor(E.ActionBar,index,"TOPRIGHT","BOTTOMLEFT",g.auxRight.x+g.auxRight.w-12,g.auxRightTop)
        end
        if not dashboardOnly then anchor(E.ObjectiveTracker,nil,"TOPRIGHT","TOPRIGHT",-16,-362*g.density) end
    end
    if (not dashboardOnly or upgradeUnits) and self.db.arrangeUnits then
        local U,S=Enum.EditModeUnitFrameSystemIndices,Enum.EditModeUnitFrameSetting
        if not dashboardOnly then
            for _,index in ipairs({U.Player,U.Target,U.Focus,U.Pet}) do
                H.setting(H.find(layout,E.UnitFrame,index),S.FrameSize,72*s)
            end
        end
        self:PlaceTofuUnitAnchors(layout,g)
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
        local surround=art:CreateTexture(nil,"BACKGROUND")
        surround:SetPoint("BOTTOMLEFT",art,"BOTTOMLEFT")
        surround:SetTexture(media.."TofuSurround.tga")
        surround:SetTexCoord(0,surroundWidth*2/4096,0,surroundHeight*2/1024)
        art.surround=surround
        self.tofuArt=art
    end
    local art=self.tofuArt
    art:SetShown(show)
    if not show then return end
    art:SetScale(g.scale)
    art:SetSize(1920,g.screenHeight)
    art:SetAlpha(self.db.opacity*(self.currentUIAlpha or 1))
    art.surround:SetSize(1920,surroundHeight*artScale*g.density)

end

local unitPlates=setmetatable({}, {__mode="k"})
function SD:RefreshTofuUnitArt(active,barRegion,rect)
    local show=active and self.layoutName=="Tofu Bar" and self.db.stoneUnits
    for _,frame in pairs({PlayerCastingBarFrame,CastingBarFrame,
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
    -- Edit Mode can restore the native minimum on every layout save.
    -- Fitting the row must not schedule another save.
end

SD:On("PLAYER_LOGIN",function()
    if hooksecurefunc and MainActionBar and MainActionBar.UpdateSystemSettingNumIcons then
        hooksecurefunc(MainActionBar,"UpdateSystemSettingNumIcons",function()
            if SD.layoutName=="Tofu Bar" and (MainActionBar.numButtonsShowable or 0)>5 then
                queueTopRow()
            end
        end)
    end
end)
local function finishTopRow()
    if SD.layoutName=="Tofu Bar" or SD.tofuNativeButtonCount then queueTopRow() end
end
SD:On("PLAYER_REGEN_ENABLED",finishTopRow)
