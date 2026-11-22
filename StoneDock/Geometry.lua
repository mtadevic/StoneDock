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

    if self.layoutName == "Adept" then return self:GetAdeptGeometry(width,height,rise) end
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


-- Actual visible artwork can extend outside a native container's rectangle.
function SD:GetVisibleArtworkBounds(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    local left,bottom,right,top
    local seen={}
    local function visible(f)
        if f.GetAlpha then
            local alpha=f:GetAlpha()
            if type(alpha)=="number" and (not issecretvalue or not issecretvalue(alpha)) and alpha<=0 then return false end
        end
        if f.IsVisible then return f:IsVisible() end
        return not f.IsShown or f:IsShown()
    end
    local function add(f)
        if not f.GetRect or not f.GetEffectiveScale or not visible(f) then return end
        local x,y,w,h=f:GetRect()
        for _,n in ipairs({x,y,w,h}) do
            if type(n)~="number" or (issecretvalue and issecretvalue(n)) then return end
        end
        if not x or not y or not w or not h or w<=0 or h<=0 then return end
        local scale=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
        x,y,w,h=x*scale,y*scale,w*scale,h*scale
        left=left and math.min(left,x) or x bottom=bottom and math.min(bottom,y) or y
        right=right and math.max(right,x+w) or x+w top=top and math.max(top,y+h) or y+h
    end
    local function walk(f,depth)
        if not f or seen[f] or depth>6 or not visible(f) then return end
        seen[f]=true
        local regions=f.GetRegions and {f:GetRegions()} or {}
        local children=f.GetChildren and {f:GetChildren()} or {}
        for _,region in ipairs(regions) do add(region) end
        for _,child in ipairs(children) do walk(child,depth+1) end
        if #regions==0 and #children==0 then add(f) end
    end
    walk(frame,0)
    if left then return {x=left,y=bottom,w=right-left,h=top-bottom,top=top,right=right} end
end

function SD:AppendFrameOverlapReport(lines)
    local frames,seen={},{}
    local decorative={StoneDockCanvas=true,StoneDockHUD=true,StoneDockLayoutBackdrop=true}
    local function add(name,frame)
        if not frame or seen[frame] or decorative[name] then return end
        seen[frame]=true
        local ok,bounds=pcall(self.GetVisibleArtworkBounds,self,frame)
        if not ok or not bounds then return end
        if bounds.w>UIParent:GetWidth()*.9 and bounds.h>UIParent:GetHeight()*.9 then return end
        frames[#frames+1]={name=name,frame=frame,b=bounds}
    end
    local cards=self.GetAdeptUnitCards and self:GetAdeptUnitCards() or {}
    for _,name in ipairs({"MainActionBar","MultiBarBottomLeft","MultiBarBottomRight","MultiBarRight",
        "StanceBar","PetActionBar","PossessActionBar","MicroMenu","BagsBar","BuffFrame","DebuffFrame",
        "CompactPartyFrame","CompactRaidFrameContainer","ChatFrame1","GeneralDockManager","Minimap",
        "PlayerFrame","TargetFrame","FocusFrame","TargetFrameToT","PlayerCastingBarFrame",
        "TargetFrameSpellBar","FocusFrameSpellBar","StoneDockUtilityRoot"}) do
        local frame=_G[name]
        local card=frame and cards[frame]
        if card then seen[frame]=true end
        add(name,card or frame)
    end
    add("Adept map header",self.adeptMapBorder and self.adeptMapBorder.header)
    add("Adept addon drawer",self.adeptMapDrawer)
    -- Include visible top-level windows from other addons without moving them.
    for name,frame in pairs(_G) do
        if type(name)=="string" and (type(frame)=="table" or type(frame)=="userdata") then
            -- _G also contains non-widget userdata and addon proxy tables whose
            -- field access may throw; one such object must not abort diagnostics.
            local ok,isWindow=pcall(function()
                return frame.GetName and frame.GetParent and frame.GetRect and frame.IsObjectType
                    and not (frame.IsForbidden and frame:IsForbidden())
                    and frame:IsObjectType("Frame") and frame:GetName()==name and frame:GetParent()==UIParent
            end)
            if ok and isWindow then add(name,frame) end
        end
    end
    table.sort(frames,function(a,b)return a.name<b.name end)
    lines[#lines+1]=""
    lines[#lines+1]="Visible artwork bounds (includes aura icons/timers):"
    for _,entry in ipairs(frames) do
        local b=entry.b
        lines[#lines+1]=string.format("%s: x=%.1f y=%.1f w=%.1f h=%.1f",entry.name,b.x,b.y,b.w,b.h)
    end
    local function ancestor(a,b)
        for i=1,16 do
            b=b.GetParent and b:GetParent()
            if not b then return false end
            if b==a then return true end
        end
    end
    lines[#lines+1]="Potential overlaps (parent/child containment excluded):"
    local count=0
    for i,a in ipairs(frames) do for j=i+1,#frames do
        local b=frames[j]
        local w=math.min(a.b.right,b.b.right)-math.max(a.b.x,b.b.x)
        local h=math.min(a.b.top,b.b.top)-math.max(a.b.y,b.b.y)
        local dockedTabs=(a.name=="ChatFrame1" and b.name=="GeneralDockManager")
            or (b.name=="ChatFrame1" and a.name=="GeneralDockManager")
        if w>1 and h>1 and not dockedTabs and not ancestor(a.frame,b.frame) and not ancestor(b.frame,a.frame) then
            count=count+1
            if count<=60 then lines[#lines+1]=string.format("%s / %s: %.1f x %.1f",a.name,b.name,w,h) end
        end
    end end
    if count==0 then lines[#lines+1]="None measured." end
    if count>60 then lines[#lines+1]=string.format("%d additional overlaps omitted.",count-60) end
end
