local _, SD = ...
local function rect(frame)
    if not frame or not frame.GetRect then return end
    local x,y,w,h=frame:GetRect()
    if not x or not w then return end
    local scale=frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
    return x*scale,y*scale,w*scale,h*scale
end
function SD:ConfigurePetLayout(layout)
    if not self.db.dockPet then return end
    local H=self.UnitLayoutHelpers
    local info=H.find(layout,Enum.EditModeSystem.UnitFrame,Enum.EditModeUnitFrameSystemIndices.Pet)
    if not info then return end
    info.anchorInfo={point="BOTTOMRIGHT",relativeTo="PlayerFrame",relativePoint="BOTTOMLEFT",offsetX=self.db.petOffsetX*self:GetGeometry().scale,offsetY=self.db.petOffsetY*self:GetGeometry().scale}
    if self.layoutName=="Gulveig Bar" then
        info.anchorInfo.point="TOPLEFT"
        info.anchorInfo.offsetX=(24+self.db.petOffsetX)*self:GetGeometry().scale
        info.anchorInfo.offsetY=(-26+self.db.petOffsetY)*self:GetGeometry().scale
    end
    info.anchorInfo2=nil info.isInDefaultPosition=false
    H.setting(info,Enum.EditModeUnitFrameSetting.FrameSize,self.db.petScale*self:GetGeometry().scale)
end
function SD:ApplyPetLayout()
    if self:IsBusy() or not self:IsOurLayoutActive() then return false end
    local full=self:GetFullLayouts() if not full then return false end
    local layout=full.layouts[full.activeLayout]
    local info=self.UnitLayoutHelpers.find(layout,Enum.EditModeSystem.UnitFrame,Enum.EditModeUnitFrameSystemIndices.Pet)
    local before=SD.Copy(info)
    self:ConfigurePetLayout(layout)
    if SD.Equal(before,info)then return true end
    local ok=self:Run("Dock pet frame",function()self:SaveAndRefreshLayout(full,full.activeLayout)end)
    if ok then self:CaptureProfile() end
    return ok
end
function SD:ShowPositioning()
    if self:IsBusy() then SD.Print("Finish combat and close Blizzard Edit Mode first.") return end
    if not self:IsOurLayoutActive() then SD.Print("Activate StoneDock first.") return end
    if self.positionWindow then
        local f=self.positionWindow self.positionUndo=self:SnapshotData()
        f.refreshing=true for _,slider in ipairs(f.sliders)do slider:SetValue(self.db[slider.dbKey])end f.refreshing=nil
        if f.dockCheck then f.dockCheck:SetChecked(self.db.dockPet)end
        f:Show()self:RefreshPositionHandles()self:RefreshFading(true)return
    end
    self:ClearPositionHandles()
    local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate") self.positionWindow=f
    f:SetSize(590,630) f:SetPoint("TOP",0,-45) f:SetFrameStrata("DIALOG") f:SetClampedToScreen(true)
    f:SetBackdrop({bgFile="Interface\\AddOns\\StoneDock\\Media\\Stone.tga",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=256,edgeSize=14})
    local H=self.ControlHelpers
    H.text(f,"POSITIONING",22,24,-22,540)
    H.text(f,"Drag the labeled handles. Positions snap to an 8-unit grid and nearby frame edges. Action banks share vertical placement. Combat closes this mode. Native Edit Mode remains available for all other frames.",12,24,-60,540)
    self.positionUndo=self:SnapshotData()
    f.sliders={
        H.slider(f,"Action bar width (%)","barWidth",70,110,1,24,-132,function()SD:RefreshPanels()end),
        H.slider(f,"Action-bank separation","barSpread",-100,100,1,310,-132,function()SD:RefreshPanels()end),
        H.slider(f,"Pet frame size (%)","petScale",50,150,5,24,-220),
        H.slider(f,"Pet horizontal offset","petOffsetX",-500,500,2,310,-220),
        H.slider(f,"Pet vertical offset","petOffsetY",-300,300,2,24,-306),
        H.slider(f,"Group row width (%)","groupRowWidth",70,100,1,310,-306,function()SD:QueueRaidSplit()end),
    }
    f.refreshing=true for _,s in ipairs(f.sliders)do s:SetValue(SD.db[s.dbKey])end f.refreshing=nil
    H.button(f,"Dock pet beside player",24,-394,260,function() SD.db.dockPet=true SD:ApplyPetLayout() SD:RefreshPositionHandles() end)
    H.button(f,"Apply sizing & alignment",310,-394,255,function()SD:AlignLayout() SD:ApplyPetLayout() SD:RefreshPositionHandles()end)
    local dock=H.check(f,"Keep pet frame docked beside player","dockPet",24,-490) dock:SetChecked(self.db.dockPet) f.dockCheck=dock
    H.button(f,"Blizzard Edit Mode",24,-442,260,function()f:Hide()SD:OpenEditMode()end)
    H.button(f,"Profiles & snapshots",310,-442,255,function()f:Hide()SD:ShowProfiles()end)
    H.button(f,"Cancel changes",24,-538,260,function()local undo=SD.positionUndo SD:CloseSettings()SD:RestoreSnapshotData(undo)end)
    H.button(f,"Done",310,-538,255,function()SD:AlignLayout()SD:CaptureProfile()SD:CloseSettings()end)
    f:SetScript("OnHide",function()SD:ClearPositionHandles()SD:RefreshFading()end)
    f:Show() self:RefreshPositionHandles() self:RefreshFading(true)
end
function SD:ClearPositionHandles()
    for _,h in ipairs(self.positionHandles or {})do h:StopMovingOrSizing()h:Hide()end
    self.positionHandles={}
end
function SD:MovePositionHandle(spec,x,y)
    if self:IsBusy() then return false end
    local g=self:GetGeometry()
    local function snap(v)return math.floor(v/8+.5)*8 end
    local dx,dy=(x-spec.x)/g.scale,(y-spec.y)/g.scale
    if spec.key=="bars" then
        self.db.barOffsetX=SD.Clamp(snap(self.db.barOffsetX+dx),-100,100)
        self.db.barOffsetY=SD.Clamp(snap(self.db.barOffsetY+dy/g.density),-15,180)
        self:AlignLayout()
    elseif spec.key=="groups" then
        self.db.groupOffsetX=SD.Clamp(snap(self.db.groupOffsetX+dx),-350,700)
        self.db.groupOffsetY=SD.Clamp(snap(self.db.groupOffsetY+dy),-100,500)
        self:QueueRaidSplit()
    elseif spec.key=="hud" then
        self.db.hudOffsetX=SD.Clamp(snap(self.db.hudOffsetX+dx),-600,600)
        self.db.hudOffsetY=SD.Clamp(snap(self.db.hudOffsetY+dy),-450,450)
        self:RefreshHUD()
    else
        local full=self:GetFullLayouts()if not full then return false end
        local info=self.UnitLayoutHelpers.find(full.layouts[full.activeLayout],spec.system,spec.index)
        if not info then return false end
        local tx,ty=snap(x/g.scale)*g.scale,snap(y/g.scale)*g.scale
        -- Snap matching edges when near another visible positioning target.
        for _,h in ipairs(self.positionHandles or {})do local other=h.spec
            if other~=spec then
                for _,edge in ipairs({other.x,other.x+other.w-spec.w})do if math.abs(tx-edge)<8*g.scale then tx=edge end end
                for _,edge in ipairs({other.y,other.y+other.h-spec.h})do if math.abs(ty-edge)<8*g.scale then ty=edge end end
            end
        end
        self.UnitLayoutHelpers.anchor(info,"BOTTOMLEFT","BOTTOMLEFT",tx,ty)
        if spec.index==Enum.EditModeUnitFrameSystemIndices.Pet and spec.system==Enum.EditModeSystem.UnitFrame then self.db.dockPet=false end
        self:SaveAndRefreshLayout(full,full.activeLayout)
    end
    self:CaptureProfile() self:RefreshPanels()
    return true
end
function SD:RefreshPositionHandles()
    self:ClearPositionHandles()
    if not self.positionWindow or not self.positionWindow:IsShown() or InCombatLockdown() then return end
    local g=self:GetGeometry()local U=Enum.EditModeUnitFrameSystemIndices
    local specs={
        {key="bars",label="ACTION BANKS",x=g.leftWell.x*g.scale,y=g.leftWell.y*g.scale,w=g.leftWell.w*g.scale,h=g.leftWell.h*g.scale},
        {key="groups",label="PARTY / RAID",x=(g.leftWell.x+self.db.groupOffsetX)*g.scale,y=(g.leftWell.y+g.leftWell.h+15+self.db.groupOffsetY)*g.scale,w=g.leftWell.w*g.scale,h=24*g.scale},
        {key="hud",label="CURVED HUD",x=(960+self.db.hudOffsetX)*g.scale-90,y=(g.screenHeight/2+self.db.hudOffsetY)*g.scale,w=180,h=40},
    }
    for _,entry in ipairs({{PlayerFrame,U.Player,"PLAYER"},{TargetFrame,U.Target,"TARGET"},{FocusFrame,U.Focus,"FOCUS"},{PetFrame,U.Pet,"PET"}})do
        local x,y,w,h=rect(entry[1])
        if x then specs[#specs+1]={label=entry[3],system=Enum.EditModeSystem.UnitFrame,index=entry[2],x=x,y=y,w=w,h=h}end
    end
    self.positionHandlePool=self.positionHandlePool or {}
    for i,spec in ipairs(specs)do
        local h=self.positionHandlePool[i]
        if not h then h=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")self.positionHandlePool[i]=h end
        h.spec=spec h:ClearAllPoints()
        h:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",spec.x,spec.y)h:SetSize(spec.w,spec.h)h:SetFrameStrata("DIALOG")
        h:SetMovable(true)h:SetClampedToScreen(true)h:EnableMouse(true)h:RegisterForDrag("LeftButton")
        h:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})h:SetBackdropColor(.1,.3,.4,.25)h:SetBackdropBorderColor(.4,.7,.8,1)
        local label=h.label or h:CreateFontString(nil,"OVERLAY","GameFontNormal")h.label=label label:SetPoint("CENTER")label:SetText(spec.label)
        h:SetScript("OnDragStart",function()if not InCombatLockdown()then h:StartMoving()end end)
        h:SetScript("OnDragStop",function()h:StopMovingOrSizing()local x,y=rect(h)if x then SD:MovePositionHandle(spec,x,y)end SD:RefreshPositionHandles()end)
        self.positionHandles[#self.positionHandles+1]=h h:Show()
    end
end
SD:On("PLAYER_REGEN_DISABLED",function()if SD.positionWindow then SD.positionWindow:Hide()end end)
local function initializePetDocking()
    SD.petDockAfterCombat = nil
    if not SD.db.dockPet then return end
    if InCombatLockdown() then
        SD.petDockAfterCombat = true
    elseif not SD:IsBusy() then
        SD:ApplyPetLayout()
    end
end
SD:On("PLAYER_LOGIN",function()
    C_Timer.After(3,function() SD:Run("Initialize pet docking",initializePetDocking) end)
end)
SD:On("PLAYER_REGEN_ENABLED",function()
    if SD.petDockAfterCombat then initializePetDocking() end
end)
