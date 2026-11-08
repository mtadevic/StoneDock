local _, SD = ...
local media = "Interface\\AddOns\\StoneDock\\Media\\"
local font = "Fonts\\FRIZQT__.TTF"
local stoneTextures = {
    classic = "Stone.tga",
    weathered = "WeatheredStone.tga",
    carved = "CarvedStone.tga",
    kintsugi = "OnyxKintsugi.tga",
}

local function line(parent, x, y, w, h, r, g, b, a)
    local texture = parent:CreateTexture(nil, "BORDER")
    texture:SetColorTexture(r, g, b, a or 1)
    texture:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, y)
    texture:SetSize(w, h)
    return texture
end

local function text(parent, size, justify)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(font, size, "")
    label:SetTextColor(0.69, 0.72, 0.75)
    label:SetShadowOffset(1, -1)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetJustifyH(justify or "LEFT")
    return label
end

local function panel(parent, name)
    local frame = CreateFrame("Frame", nil, parent)
    frame:EnableMouse(false)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(3)
    frame.fill = frame:CreateTexture(nil, "BACKGROUND")
    frame.fill:SetAllPoints()
    frame.fill:SetTexture(media .. "Stone.tga", "REPEAT", "REPEAT")
    frame.shadow = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.shadow:SetAllPoints()
    frame.shadow:SetTexture(media .. "Shade.tga")
    frame.trim = {}
    for i = 1, 8 do frame.trim[i] = line(frame, 0, 0, 1, 1, 0, 0, 0) end
    frame.rivets = {}
    for i = 1, 4 do
        local rivet = frame:CreateTexture(nil, "ARTWORK")
        rivet:SetTexture(media .. "Rivet.tga")
        rivet:SetSize(11, 11)
        frame.rivets[i] = rivet
    end
    frame.caption = text(frame, 11)
    frame.caption:SetPoint("TOPLEFT", 16, -13)
    frame.caption:SetText(name or "")
    return frame
end

local function place(frame, rect)
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", SD.canvas, "BOTTOMLEFT", rect.x, rect.y)
    frame:SetSize(rect.w, rect.h)
    frame.fill:SetTexCoord(0, rect.w / 512, 0, rect.h / 512)
    local w, h = rect.w, rect.h
    local specs = {
        { 0, 0, w, 2 }, { 0, h - 2, w, 2 }, { 0, 0, 2, h }, { w - 2, 0, 2, h },
        { 3, h - 4, w - 6, 1 }, { 3, 3, w - 6, 1 }, { 3, 3, 1, h - 6 }, { w - 4, 3, 1, h - 6 },
    }
    local accent = SD.colors[SD.db.accent]
    for i, spec in ipairs(specs) do
        local t = frame.trim[i]
        t:ClearAllPoints()
        t:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", spec[1], spec[2])
        t:SetSize(spec[3], spec[4])
        if i <= 4 then t:SetColorTexture(0.035, 0.043, 0.052, 1)
        else t:SetColorTexture(accent[1], accent[2], accent[3], i == 5 and 0.64 or 0.23) end
    end
    local points = { { "TOPLEFT", 5, -5 }, { "TOPRIGHT", -5, -5 }, { "BOTTOMLEFT", 5, 5 }, { "BOTTOMRIGHT", -5, 5 } }
    for i, p in ipairs(points) do
        frame.rivets[i]:ClearAllPoints()
        frame.rivets[i]:SetPoint(p[1], frame, p[1], p[2], p[3])
    end
    frame.caption:SetShown(SD.db.showLabels)
end

function SD:CreatePanels()
    if self.canvas then return end
    self.canvas = CreateFrame("Frame", "StoneDockCanvas", UIParent)
    self.canvas:SetFrameStrata("BACKGROUND")
    self.canvas:SetFrameLevel(0)
    self.canvas:EnableMouse(false)
    self.panels = {
        base = panel(self.canvas),
        left = panel(self.canvas, "CONVERSATION"),
        right = panel(self.canvas, "FIELD NOTES"),
        leftWell = panel(self.canvas),
        rightWell = panel(self.canvas),
        map = panel(self.canvas),
        menuDrawer = panel(self.canvas),
        bagDrawer = panel(self.canvas),
    }
    for _, key in ipairs({ "left", "right", "leftWell", "rightWell", "map" }) do
        local frame = self.panels[key]
        local frieze = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
        frieze:SetTexture(media .. "CarvedFrieze.tga", "REPEAT", "CLAMP")
        frieze:SetPoint("TOPLEFT", frame, "TOPLEFT", 17, -5)
        frieze:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -17, -5)
        frieze:SetHeight(7)
        frieze:SetAlpha(0.65)
        frame.frieze = frieze
    end
    for _, key in ipairs({ "base", "leftWell", "rightWell", "map" }) do self.panels[key].caption:Hide() end
    self.panels.base.fill:SetVertexColor(0.75, 0.75, 0.78)
    self.panels.base:SetFrameLevel(1)
    self.panels.leftWell.fill:SetVertexColor(0.55, 0.57, 0.60)
    self.panels.rightWell.fill:SetVertexColor(0.55, 0.57, 0.60)
    self.panels.map.fill:SetVertexColor(0.78, 0.80, 0.84)
    for _, key in ipairs({ "menuDrawer", "bagDrawer" }) do
        local drawer = self.panels[key]
        drawer:SetFrameLevel(5)
        drawer.fill:SetVertexColor(0.40, 0.43, 0.48)
        drawer.handle = line(drawer, (316 - 32) / 2, 5, 32, 2, 0.32, 0.36, 0.40, 1)
    end

    local right = self.panels.right
    self.info = {}
    for _, key in ipairs({ "zone", "clock", "money", "bags", "performance", "hint" }) do self.info[key] = text(right, key == "zone" and 13 or 11) end
    self.info.zone:SetPoint("TOPLEFT", 17, -37)
    self.info.zone:SetPoint("TOPRIGHT", -17, -37)
    self.info.zone:SetWordWrap(false)
    self.info.clock:SetPoint("TOPLEFT", 18, -56)
    self.info.money:SetPoint("TOPRIGHT", -18, -56)
    self.info.bags:SetPoint("TOPLEFT", 18, -75)
    self.info.performance:SetPoint("TOPRIGHT", -18, -75)
    self.info.hint:SetPoint("TOPLEFT", 18, -119)
    self.info.hint:SetText("/stonedock  |  layout & appearance")
    self.info.hint:SetTextColor(0.42, 0.47, 0.52)

    self.brand = text(self.canvas, 10, "CENTER")
    self.brand:SetPoint("BOTTOM", self.canvas, "BOTTOM", 0, 6)
    self.brand:SetText("S T O N E D O C K")
    self.brand:SetTextColor(0.48, 0.53, 0.58)
    self.guides = CreateFrame("Frame", nil, self.canvas)
    self.guides:SetAllPoints()
    self.guides:SetFrameStrata("MEDIUM")
    self.guides:EnableMouse(false)
    self.guideLabels = {}
    for _, label in ipairs({ "PLAYER", "TARGET", "PARTY / RAID", "CAST BAR", "MINIMAP", "ACTION BARS", "CHAT" }) do
        local f = CreateFrame("Frame", nil, self.guides)
        f.fill = f:CreateTexture(nil, "BACKGROUND")
        f.fill:SetAllPoints()
        f.fill:SetColorTexture(0.10, 0.18, 0.25, 0.65)
        f.label = text(f, 12, "CENTER")
        f.label:SetAllPoints()
        f.label:SetText(label)
        self.guideLabels[label] = f
    end
end

function SD:RefreshPanels()
    if not self.canvas then return end
    local g = self:GetGeometry()
    self.geometry = g
    self.canvas:ClearAllPoints()
    self.canvas:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
    self.canvas:SetSize(1920, g.screenHeight)
    self.canvas:SetScale(g.scale)
    self.canvas:SetAlpha(self.db.opacity * (self.currentUIAlpha or 1))
    local theme = self.db.stoneTexture
    local texture = media .. (stoneTextures[theme] or stoneTextures.weathered)
    for key, frame in pairs(self.panels) do
        frame.fill:SetTexture(texture, "REPEAT", "REPEAT")
        local tint={base={.75,.75,.78},leftWell={.55,.57,.60},rightWell={.55,.57,.60},map={.78,.80,.84},menuDrawer={.40,.43,.48},bagDrawer={.40,.43,.48}}
        local color=theme=="kintsugi" and {1,1,1} or tint[key] or {1,1,1}
        frame.fill:SetVertexColor(unpack(color))
        frame.caption:SetTextColor(theme=="kintsugi" and .83 or .69,theme=="kintsugi" and .67 or .72,theme=="kintsugi" and .43 or .75)
        for _,rivet in ipairs(frame.rivets) do rivet:SetVertexColor(1,theme=="kintsugi" and .76 or 1,theme=="kintsugi" and .43 or 1) end
        place(frame, g[key])
        if frame.frieze then
            frame.frieze:SetTexCoord(0, (g[key].w - 34) / 64, 0, 1)
            frame.frieze:SetShown(theme == "carved")
        end
    end
    for _, key in ipairs({ "base", "leftWell", "rightWell", "map" }) do self.panels[key].caption:Hide() end
    self.brand:SetShown(self.db.showLabels)
    for _, label in pairs(self.info) do label:SetShown(self.db.showInfo) end
    self.info.hint:Hide()

    local positions = {
        ["PLAYER"] = { 24, g.player.y + 10, 250, 65 },
        ["TARGET"] = { 1920 - 274, g.target.y + 10, 250, 65 },
        ["PARTY / RAID"] = { g.party.x, g.party.y, 400, 70 },
        ["CAST BAR"] = { 810, g.cast.y, 300, 24 },
        ["MINIMAP"] = { g.map.x + 12, g.map.y + 28, g.map.w - 24, 145 * g.density },
        ["ACTION BARS"] = { g.leftWell.x + 10, g.leftWell.y + 12, g.leftWell.w - 20, g.leftWell.h - 24 },
        ["CHAT"] = { g.chat.x, g.chat.y, g.chat.w, g.chat.h },
    }
    for label, p in pairs(positions) do
        local f = self.guideLabels[label]
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", self.canvas, "BOTTOMLEFT", p[1], p[2])
        f:SetSize(p[3], p[4])
    end
    self.guides:SetShown(self.db.showGuides)
    -- Follow the active native layout instead of leaving artwork over another UI.
    local show = self.db.enabled and (self:IsOurLayoutActive() or self.db.showGuides)
    self.canvas:SetShown(show and not self.editing)
    self.fadeLayoutActive=self:IsOurLayoutActive()
    if self.options and self.options:IsShown() and self.options.Refresh then self.options:Refresh() end
    self:UpdateInfo()
    self:RefreshHUD()
    if self.RefreshDocking then self:RefreshDocking() end
    if self.RefreshFading then self:RefreshFading() end
    if self.RefreshUnitTrim then self:RefreshUnitTrim() end
    if self.RefreshUtilityButtons then self:RefreshUtilityButtons() end
    if self.raidPreview then self:PreviewRaid(self.raidPreview.count) end
    if self.QueueRaidSplit then self:QueueRaidSplit() end
    self:StartInfoTicker()
    if self.RefreshRivetVisibility then self:RefreshRivetVisibility()end
end

function SD:SetEditing(editing)
    self.editing = editing
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
