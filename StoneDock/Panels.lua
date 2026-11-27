local _, SD = ...
function SD:CreatePanels()
    if self.canvas then return end
    self.canvas=CreateFrame("Frame","StoneDockCanvas",UIParent)
    self.canvas:SetFrameStrata("BACKGROUND") self.canvas:SetFrameLevel(0)
    self.canvas:EnableMouse(false)
    self.guides=CreateFrame("Frame",nil,self.canvas)
    self.guides:SetAllPoints() self.guides:SetFrameStrata("MEDIUM") self.guides:EnableMouse(false)
    self.guideLabels={}
    for _,name in ipairs({"PLAYER","TARGET","PARTY / RAID","CAST BAR","MINIMAP","ACTION BARS","CHAT"}) do
        local f=CreateFrame("Frame",nil,self.guides)
        f.fill=f:CreateTexture(nil,"BACKGROUND") f.fill:SetAllPoints() f.fill:SetColorTexture(.1,.18,.25,.65)
        f.label=f:CreateFontString(nil,"OVERLAY") f.label:SetFont("Fonts\\FRIZQT__.TTF",12,"") f.label:SetAllPoints() f.label:SetText(name)
        self.guideLabels[name]=f
    end
end
function SD:UpdateInfo() self:UpdateAdeptConsole() end
function SD:RefreshPanels()
    if not self.canvas then return end
    local g=self:GetGeometry() self.geometry=g
    self.canvas:ClearAllPoints() self.canvas:SetPoint("BOTTOM",UIParent,"BOTTOM",0,0)
    self.canvas:SetSize(1920,g.screenHeight) self.canvas:SetScale(g.scale)
    self.canvas:SetAlpha(self.db.opacity*(self.currentUIAlpha or 1))
    self:RefreshAdeptArt(g) self:RefreshAdeptEnemies(g) self:RefreshAdeptMinimap()
    local positions={
        ["PLAYER"]={g.player.x-110,g.player.y,220,60},["TARGET"]={g.target.x-110,g.target.y,220,60},
        ["PARTY / RAID"]={g.party.x,g.party.y,560,40},["CAST BAR"]={810,g.cast.y,300,24},
        ["MINIMAP"]={g.map.x,g.map.y,g.map.w,g.map.h},
        ["ACTION BARS"]={g.leftWell.x,g.leftWell.y,g.leftWell.w,g.leftWell.h},
        ["CHAT"]={g.chat.x,g.chat.y,g.chat.w,g.chat.h},
    }
    for name,p in pairs(positions) do
        local f=self.guideLabels[name] f:ClearAllPoints() f:SetPoint("BOTTOMLEFT",self.canvas,"BOTTOMLEFT",p[1],p[2]) f:SetSize(p[3],p[4])
    end
    self.guides:SetShown(self.db.showGuides)
    self.canvas:SetShown(self.db.enabled and (self:IsOurLayoutActive() or self.db.showGuides))
    self.fadeLayoutActive=self:IsOurLayoutActive()
    if self.options and self.options:IsShown() and self.options.Refresh then self.options:Refresh() end
    self:UpdateInfo() self:RefreshHUD() self:RefreshDocking() self:RefreshFading()
    self:RefreshUnitTrim() self:RefreshUtilityButtons()
    if self.raidPreview then self:PreviewRaid(self.raidPreview.count) end
    self:QueueRaidSplit() self:StartInfoTicker()
end

function SD:SetEditing(editing)
    self.editing = editing
    if not editing and self.welcomePending then self:PromptForLayout() end
    if not editing and self.CheckLoginAlignment then C_Timer.After(0.1,function() SD:CheckLoginAlignment() end) end
    if self.canvas then self:RefreshPanels() end
end

function SD:StartInfoTicker()
    local needed=self.canvas and self.canvas:IsShown() and self.db.showInfo
    if not needed and self.infoTicker then self.infoTicker:Cancel()self.infoTicker=nil end
    if not needed or self.infoTicker then return end
    self.infoTicker = C_Timer.NewTicker(2, function()
        if SD.canvas and SD.canvas:IsShown() and SD.db.showInfo then SD:Run("Status panel", function() SD:UpdateInfo() end) end
    end)
end
