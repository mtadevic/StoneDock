local _, SD = ...
local names={stone="StoneDock - Dark Stone",gulveig="Gulveig Bar"}
local function variant(name)
    for key,value in pairs(names) do if value==name then return key end end
end

function SD:InitializeLayoutVariant()
    local active=self:GetActiveLayout()
    local key=active and variant(active.layoutName) or self.db.layoutVariant
    if not names[key] then key="stone" end
    self.db.layoutVariant=key
    self.layoutName=names[key]
end

-- Never share native unit/aura/tracking anchors between the two designs.
function SD:GetVariantProfileStore()
    if self.layoutName~=names.gulveig then return self.profile,"native" end
    self.profile.variantNative=self.profile.variantNative or {}
    return self.profile.variantNative,"gulveig"
end

function SD:ActivateLayoutVariant(key)
    if not names[key] or self:IsBusy() then return false end
    local oldName=self.layoutName
    if self.CaptureProfile then self:CaptureProfile() end
    self.variantSwitching=true
    self.layoutName=names[key]
    local ok,err=pcall(self.ActivateLayout,self)
    self.variantSwitching=nil
    if not ok or not self:IsOurLayoutActive() then
        self.layoutName=oldName self.db.layoutVariant=variant(oldName) or "stone"
        if not ok then self:ReportError("Switch layout",err) end
        return false
    end
    self.db.layoutVariant=key
    -- Each native layout already owns its saved anchors. Do not restore the
    -- other design's character profile or geometry over them when switching.
    self.db.nativeGeometry=nil
    self.profileNeedsRestore=nil
    self:CaptureProfile()
    self:RefreshPanels()
    return true
end

SD:On("EDIT_MODE_LAYOUTS_UPDATED",function()
    if not SD.db or SD.layoutWriteBusy or SD.variantSwitching then return end
    local active=SD:GetActiveLayout()
    local key=active and variant(active.layoutName)
    if key and SD.layoutName~=names[key] then
        SD.layoutName=names[key] SD.db.layoutVariant=key
        SD.db.nativeGeometry=nil SD.profileNeedsRestore=nil
    end
end)

function SD:GetGulveigGeometry(width,height,rise)
    local scale=width/1920
    local dx,dy=self.db.barOffsetX,self.db.barOffsetY
    local stretch=self.db.barWidth/100
    local function r(x,y,w,h)return {x=x,y=y*rise,w=w,h=h*rise}end
    return {
        variant="gulveig",width=width,height=height,scale=scale,density=rise,screenHeight=height/scale,
        base=r(0,0,1920,1),left=r(20,90,420,160),right=r(1440,300,440,160),
        leftWell=r(40,250,440,20),rightWell=r(1440,250,440,20),
        map=r(1640,22,250,260),chat=r(30,100,400,135),
        menuDrawer=r(25,4,410,38),bagDrawer=r(25,47,410,36),utilityY=260*rise,
        bars={
            {index=1,x=960+dx,y=(241+dy)*rise,icons=6,iconSize=58*stretch*rise},
            {index=2,x=960+dx,y=(156+dy)*rise,icons=6,iconSize=70*stretch*rise},
            {index=3,x=960+dx,y=(75+dy)*rise,icons=6,iconSize=58*stretch*rise},
        },
        ornament=r(510+dx,24+dy,900*stretch,270),
        trackingWell=r(480,-100,960,115),
        auxLeft=r(550+dx,300+dy,390,20),auxRight=r(980+dx,300+dy,390,20),
        player={x=210,y=400*rise},target={x=1710,y=400*rise},
        cast={x=-540,y=370*rise},party={x=40,y=300*rise},raid={x=40,y=370*rise},
    }
end

function SD:FinishGulveigLayout(layout,g,fresh)
    local H,E=self.UnitLayoutHelpers,Enum.EditModeSystem
    if not H then return end
    local s,U=g.scale,Enum.EditModeUnitFrameSystemIndices
    local function anchor(system,index,point,relative,x,y)
        H.anchor(H.find(layout,system,index),point,relative,x*s,y*s)
    end
    if self.db.arrangeUtility then
        anchor(E.StatusTrackingBar,1,"BOTTOM","BOTTOM",0,5*g.density)
        anchor(E.StatusTrackingBar,2,"BOTTOM","BOTTOM",0,18*g.density)
    end
    for _,entry in ipairs({{11,g.auxLeft,"BOTTOMRIGHT"},{12,g.auxRight,"BOTTOMLEFT"},{13,g.auxRight,"BOTTOMLEFT"}}) do
        local well=entry[2]
        anchor(E.ActionBar,entry[1],entry[3],"BOTTOMLEFT",well.x+(entry[1]==11 and well.w-12 or 12),well.y+well.h-18*g.density)
    end
    if fresh and self.db.arrangeUnits then
        local player=H.find(layout,E.UnitFrame,U.Player)
        H.setting(player,Enum.EditModeUnitFrameSetting.CastBarUnderneath,1)
        anchor(E.UnitFrame,U.Pet,"TOPLEFT","BOTTOMLEFT",240,365*g.density)
        anchor(E.UnitFrame,U.Focus,"BOTTOMRIGHT","BOTTOMLEFT",1700,550*g.density)
    end
    if fresh then
        anchor(E.CastBar,nil,"BOTTOM","BOTTOM",g.cast.x,g.cast.y)
    end
end

function SD:RefreshVariantArt(g)
    local gulveig=g.variant=="gulveig"
    for _,key in ipairs({"base","leftWell","rightWell","map","right"}) do
        self.panels[key]:SetShown(not gulveig)
    end
    if not self.gulveigArt then
        local art=self.canvas:CreateTexture(nil,"ARTWORK")
        art:SetTexture("Interface\\AddOns\\StoneDock\\Media\\GulveigBar.tga")
        self.gulveigArt=art
    end
    self.gulveigArt:SetShown(gulveig)
    if gulveig then
        local r=g.ornament
        self.gulveigArt:ClearAllPoints()
        self.gulveigArt:SetPoint("BOTTOMLEFT",self.canvas,"BOTTOMLEFT",r.x+(900-r.w)/2,r.y)
        self.gulveigArt:SetSize(r.w,r.h)
    end
end

function SD:ChooseFirstLayout(key)
    if not self:ActivateLayoutVariant(key) then return false end
    StoneDockCharDB.welcomed=true
    self.welcomePending=nil
    if self.layoutChooser then self.layoutChooser:Hide() end
    SD.Print("Layout ready. Change layouts anytime in Theme & layout.")
    return true
end

function SD:PromptForLayout()
    if StoneDockCharDB.welcomed then return end
    if self:IsBusy() then self.welcomePending=true return end
    self.welcomePending=nil
    if not self.layoutChooser then
        local create,H=self:WindowBuilder("layoutChooser")
        local f=create("Frame","StoneDockLayoutChooser",UIParent,"BackdropTemplate")
        self.layoutChooser=f
        f:SetSize(560,330) f:SetPoint("CENTER") f:SetFrameStrata("DIALOG")
        f:SetClampedToScreen(true) self:StyleCard(f,false)
        H.text(f,"Welcome to StoneDock",23,24,-24,510)
        H.text(f,"Choose your starting layout",15,24,-66,510)
        H.text(f,"StoneDock dashboard: split action banks, centered map and a tools panel.\n\nGulveig Bar: Celtic trim, three centered action rows, flanking unit frames and a bottom-right map.",13,24,-100,510)
        f.selection=self.db.layoutVariant or "stone"
        f.choice=self:SettingsDropdown(f,"Layout",{{"stone","StoneDock dashboard"},{"gulveig","Gulveig Bar"}},
            function()return f.selection end,function(key)f.selection=key end,create)
        f.choice:SetPoint("TOPLEFT",24,-218)
        f.apply=H.button(f,"Use this layout",24,-272,248,function()SD:ChooseFirstLayout(f.selection)end)
        f.later=H.button(f,"Decide later",288,-272,248,function()f:Hide()end)
        UISpecialFrames[#UISpecialFrames+1]="StoneDockLayoutChooser"
    end
    self.layoutChooser:Show()
end

SD:On("PLAYER_REGEN_ENABLED",function()if SD.welcomePending then SD:PromptForLayout() end end)
