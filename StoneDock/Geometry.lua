local _, SD = ...

-- All artwork is laid out on a 1920-wide design canvas. Native Edit Mode
-- anchors are converted back to UIParent units; we never change global UI scale.
function SD:GetGeometry(width, height, density)
    width = width or UIParent:GetWidth()
    height = height or UIParent:GetHeight()
    density = density or self.db.density
    local scale = width / 1920
    -- Fit the dashboard vertically on wide displays while still spanning the screen.
    local rise = density * math.min(1, (height / width) / (9 / 16))
    local _,_,_,interface=GetBuildInfo()
    local menuHeight=interface==16001 and 44 or 36
    local bagY=12+menuHeight+7
    local side = 354
    local center = 192
    local gap = 18
    local wellWidth = (1920 - side * 2 - center - gap * 4) / 2
    local mapLeft = (1920 - center) / 2
    local leftWell = side + gap
    local rightWell = mapLeft + center + gap
    local dx = self.db and self.db.barOffsetX or 0
    local dy = self.db and self.db.barOffsetY or 0
    local spread = self.db and self.db.barSpread or 0
    local widthPercent = self.db and self.db.barWidth or 100
    local adjustedWidth = wellWidth * widthPercent / 100
    leftWell = leftWell + dx - spread + (wellWidth-adjustedWidth)/2
    rightWell = rightWell + dx + spread + (wellWidth-adjustedWidth)/2
    wellWidth = adjustedWidth
    local function rect(x, y, w, h)
        return { x = x, y = y * rise, w = w, h = h * rise }
    end
    if self.layoutName == "Tofu Bar" then return self:GetTofuGeometry(width,height,rise) end

    if self.layoutName == "Gulveig Bar" then return self:GetGulveigGeometry(width,height,rise) end
    return {
        width = width, height = height, scale = scale, density = rise, revision = 1,
        screenHeight = height / scale,
        base = rect(0, 0, 1920, 144),
        left = rect(10, 8, side - 10, 228),
        right = rect(1920-side,8,side-10,228),
        menuDrawer = rect(1920 - side + 14, 12, side - 38, menuHeight),
        bagDrawer = rect(1920 - side + 14, bagY, side - 38, 36),
        utilityY = (bagY+44)*rise,
        leftWell = rect(leftWell, 17 + dy, wellWidth, 121),
        rightWell = rect(rightWell, 17 + dy, wellWidth, 121),
        map = rect(mapLeft, 7, center, 228),
        chat = rect(27, 47, side - 54, 142),
        bars = {
            { index = 1, x = leftWell + wellWidth / 2, y = (57 + dy) * rise },
            { index = 2, x = leftWell + wellWidth / 2, y = (94 + dy) * rise },
            { index = 3, x = rightWell + wellWidth / 2, y = (57 + dy) * rise },
            { index = 4, x = rightWell + wellWidth / 2, y = (94 + dy) * rise },
        },
        cast = { x = 0, y = 254 * rise },
        player = { x = leftWell + wellWidth - 238, y = 254 * rise },
        target = { x = rightWell + 200, y = 254 * rise },
        party = { x = leftWell + 12, y = 277 * rise },
        raid = { x = leftWell + 12, y = 380 * rise },
    }
end

function SD:RectToParent(rect, geometry)
    local scale = (geometry or self:GetGeometry()).scale
    return rect.x * scale, rect.y * scale, rect.w * scale, rect.h * scale
end
