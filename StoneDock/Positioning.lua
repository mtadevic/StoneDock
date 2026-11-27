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
