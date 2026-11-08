local _, SD = ...
local media="Interface\\AddOns\\StoneDock\\Media\\"
local function arc(parent,asset,point,r,g,b)
    local bar=CreateFrame("StatusBar",nil,parent)
    bar:SetPoint(point,parent,point,0,0)bar:SetOrientation("VERTICAL")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")bar:SetStatusBarColor(r,g,b,.92)
    bar:SetMinMaxValues(0,1)bar:SetValue(1)
    bar.rim=bar:CreateTexture(nil,"BACKGROUND",nil,-2)
    bar.rim:SetPoint("TOPLEFT",-1.5,1.5)bar.rim:SetPoint("BOTTOMRIGHT",1.5,-1.5)
    bar.rim:SetTexture(media..asset)bar.rim:SetVertexColor(.36,.34,.29,.75)
    bar.track=bar:CreateTexture(nil,"BACKGROUND",nil,-1)bar.track:SetAllPoints()
    bar.track:SetTexture(media..asset)bar.track:SetVertexColor(.065,.07,.075,.95)
    local mask=bar:CreateMaskTexture(nil,"ARTWORK")mask:SetAllPoints()
    mask:SetTexture(media..asset,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    bar:GetStatusBarTexture():AddMaskTexture(mask)
    bar.label=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    bar.label:SetPoint("TOP",bar,"BOTTOM",0,-8)bar.label:SetTextColor(.75,.78,.8,.95)
    bar.ticks={}
    for i=1,3 do
        local tick=bar:CreateTexture(nil,"OVERLAY")tick:SetColorTexture(.04,.045,.05,.85)bar.ticks[i]=tick
    end
    return bar
end
local events={"UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_POWER_UPDATE","UNIT_MAXPOWER","UNIT_DISPLAYPOWER"}
function SD:CreateHUD()
    if self.hud then return end
    local f=CreateFrame("Frame","StoneDockHUD",UIParent)self.hud=f
    f:SetFrameStrata("LOW")f:EnableMouse(false)
    f.health=arc(f,"ArcLeft.tga","LEFT",.78,.15,.19)
    f.resource=arc(f,"ArcRight.tga","RIGHT",.44,.31,.76)
    f.health.label:SetText("HEALTH")
    f.events=CreateFrame("Frame")
    f.events:SetScript("OnEvent",function(_,event)
        if f:IsShown()then SD:Run("Player HUD",function()SD:UpdateHUD(event)end)end
    end)
    self:RefreshHUD()
end
function SD:RefreshHUD()
    if not self.hud then return end
    local f,g=self.hud,self:GetGeometry()
    local width,height=self.db.hudArcWidth or 48,self.db.hudHeight or 210
    f:ClearAllPoints()f:SetSize(self.db.hudGap+width*2,height)
    f:SetPoint("CENTER",UIParent,"CENTER",self.db.hudOffsetX/self.db.hudScale,self.db.hudOffsetY/self.db.hudScale)
    f:SetScale(g.scale*self.db.hudScale)
    for side,bar in ipairs({f.health,f.resource})do
        bar:SetSize(width,height)bar.label:SetShown(self.db.hudLabels~=false)
        for i,tick in ipairs(bar.ticks)do
            local p=i/4
            local x=(35+.00044*(p*1024-512)^2)/192*width
            if side==2 then x=width-x end
            tick:ClearAllPoints()tick:SetPoint("CENTER",bar,"BOTTOMLEFT",x,p*height)
            tick:SetSize(8,1.2)tick:SetShown(self.db.hudTicks~=false)
        end
    end
    if self.db.hudHealthColor=="class"and UnitClass and RAID_CLASS_COLORS then
        local _,class=UnitClass("player")local color=RAID_CLASS_COLORS[class]
        if color then f.health:SetStatusBarColor(color.r,color.g,color.b,.92)end
    else f.health:SetStatusBarColor(.78,.15,.19,.92)end
    local shown=self.db.showHUD and self.db.enabled and not self.editing and(self:IsOurLayoutActive()or self.db.showGuides)
    f:SetShown(shown)
    if shown~=f.listening then
        f.events:UnregisterAllEvents()
        if shown then for _,event in ipairs(events)do f.events:RegisterUnitEvent(event,"player")end f.events:RegisterEvent("PLAYER_ENTERING_WORLD")end
        f.listening=shown
    end
    if shown then self:UpdateHUD()end
    if self.RefreshFading then self:RefreshFading()end
end
function SD:UpdateHUD(event)
    if not self.hud then return end
    -- Pass opaque vitals directly to native status bars. Decoration never
    -- compares, divides, formats or stores health/resource values.
    if not event or event=="PLAYER_ENTERING_WORLD"or event=="UNIT_HEALTH"or event=="UNIT_MAXHEALTH"then
        self.hud.health:SetMinMaxValues(0,UnitHealthMax("player"))
        self.hud.health:SetValue(UnitHealth("player"))
    end
    if not event or event=="PLAYER_ENTERING_WORLD"or event=="UNIT_POWER_UPDATE"or event=="UNIT_MAXPOWER"or event=="UNIT_DISPLAYPOWER"then
        self.hud.resource:SetMinMaxValues(0,UnitPowerMax("player"))
        self.hud.resource:SetValue(UnitPower("player"))
    end
    if not event or event=="PLAYER_ENTERING_WORLD"or event=="UNIT_DISPLAYPOWER"then
        local kind,token if UnitPowerType then kind,token=UnitPowerType("player")end
        local color=self.db.hudPowerColor~=false and PowerBarColor and(PowerBarColor[token]or PowerBarColor[kind])
        if color then self.hud.resource:SetStatusBarColor(color.r,color.g,color.b,.92)
        else self.hud.resource:SetStatusBarColor(.44,.31,.76,.92)end
        self.hud.resource.label:SetText(token and ((_G[token]and type(_G[token])=="string"and _G[token])or token:gsub("_"," "))or "RESOURCE")
    end
end
function SD:BuildHUDPanel()
    local CreateFrame,H=self:WindowBuilder("hudPanel")
    local f=CreateFrame("Frame",nil,UIParent)self.hudPanel=f f:SetSize(690,720)
    H.text(f,"CURVED PLAYER HUD",22,22,-22,640)
    H.text(f,"Keep the character's silhouette clear. Health is on the left; power is on the right. Tracks and quarter markers remain visible as native bars empty. Changes preview immediately.",12,22,-62,640)
    local function check(title,key,x,y)
        local b=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")b:SetSize(25,25)b:SetPoint("TOPLEFT",x,y)b:SetChecked(SD.db[key]~=false)
        H.text(b,title,12,30,-5,275)b:SetScript("OnClick",function(button)SD.db[key]=button:GetChecked()==true SD:RefreshHUD()end)
        return b
    end
    check("Enable curved HUD","showHUD",22,-115)
    check("Use native resource color","hudPowerColor",350,-115)
    check("Health / resource labels","hudLabels",22,-150)
    check("Quarter markers","hudTicks",350,-150)
    -- Sliders are cached separately from pooled dynamic text/buttons.
    if not f.sliders then
        f.sliders={
            SD.ControlHelpers.slider(f,"Separation from character","hudGap",60,500,2,22,-210,function()SD:RefreshHUD()end),
            SD.ControlHelpers.slider(f,"Arc height","hudHeight",140,280,2,350,-210,function()SD:RefreshHUD()end),
            SD.ControlHelpers.slider(f,"Horizontal position","hudOffsetX",-600,600,2,22,-285,function()SD:RefreshHUD()end),
            SD.ControlHelpers.slider(f,"Vertical position","hudOffsetY",-450,450,2,350,-285,function()SD:RefreshHUD()end),
            SD.ControlHelpers.slider(f,"Arc thickness / width","hudArcWidth",32,72,2,22,-360,function()SD:RefreshHUD()end),
            SD.ControlHelpers.slider(f,"Overall scale","hudScale",.6,1.4,.05,350,-360,function()SD:RefreshHUD()end),
        }
    end
    f.refreshing=true for _,slider in ipairs(f.sliders)do slider:SetValue(self.db[slider.dbKey])end f.refreshing=nil
    local function preset(gap,height,width)
        SD.db.hudGap=gap SD.db.hudHeight=height SD.db.hudArcWidth=width SD:RefreshHUD()SD:OpenSettingsTab("hud")
    end
    H.button(f,"Compact",22,-450,200,function()preset(176,180,40)end)
    H.button(f,"Comfortable",242,-450,200,function()preset(208,210,48)end)
    H.button(f,"Airy",462,-450,200,function()preset(256,220,48)end)
    H.button(f,"Health color: "..(self.db.hudHealthColor=="class"and "Class"or "Red"),22,-505,640,function()SD.db.hudHealthColor=SD.db.hudHealthColor=="class"and "red"or "class"SD:RefreshHUD()SD:OpenSettingsTab("hud")end)
    H.button(f,"Reset HUD placement & shape",22,-552,640,function()
        for _,key in ipairs({"hudGap","hudHeight","hudArcWidth","hudOffsetX","hudOffsetY","hudScale"})do SD.db[key]=SD.defaults[key]end
        SD:RefreshHUD()SD:OpenSettingsTab("hud")
    end)
    H.text(f,"Combat fading remains independent under Bars, HUD & fading. Your custom separation is preserved; only the old untouched default is widened automatically.",12,22,-615,640)
    return f
end
