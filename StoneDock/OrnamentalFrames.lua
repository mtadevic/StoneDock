local _,SD=...
local media="Interface\\AddOns\\StoneDock\\Media\\"
local unitArt=setmetatable({}, {__mode="k"})
local castArt=setmetatable({}, {__mode="k"})
local nativeAlpha=setmetatable({}, {__mode="k"})

local function readable(value)
    return not issecretvalue or not issecretvalue(value)
end
local function usableNumber(value)
    return readable(value) and type(value)=="number"
end

local function suppress(region,state)
    if not region or not region.GetAlpha then return end
    if state then
        if nativeAlpha[region]==nil then
            local alpha=region:GetAlpha()
            if not usableNumber(alpha) then return end
            nativeAlpha[region]=alpha
        end
        region:SetAlpha(0)
    elseif nativeAlpha[region]~=nil then region:SetAlpha(nativeAlpha[region]) nativeAlpha[region]=nil end
end

-- Nine pieces keep the small metal bevels intact as native frames change size.
function SD:CreateGulveigBorder(parent, endWidth, edgeHeight)
    endWidth=endWidth or 6
    edgeHeight=edgeHeight or 6
    local f=CreateFrame("Frame",nil,parent)
    f:EnableMouse(false)
    f.fill=parent:CreateTexture(nil,"BACKGROUND",nil,-7)
    f:SetScript("OnShow",function() f.fill:Show() end)
    f:SetScript("OnHide",function() f.fill:Hide() end)
    f.fill:SetColorTexture(0,0,0,.92)
    f.fill:SetPoint("TOPLEFT",f,"TOPLEFT",endWidth*.72,-edgeHeight)
    f.fill:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-endWidth*.72,edgeHeight)
    local u,v={0,.1,.9,1},{.18,.31,.68,.81}
    for row=1,3 do
        for col=1,3 do
            if row~=2 or col~=2 then
                local t=f:CreateTexture(nil,"OVERLAY",nil,5)
                t:SetTexture(media.."GulveigRailV2.tga")
                t:SetTexCoord(u[col],u[col+1],v[row],v[row+1])
                local left=col==1 and 0 or endWidth
                local right=col==3 and 0 or -endWidth
                local top=row==1 and 0 or -edgeHeight
                local bottom=row==3 and 0 or edgeHeight
                t:SetPoint("TOPLEFT",f,col==3 and "TOPRIGHT" or "TOPLEFT",col==3 and -endWidth or left,top)
                t:SetPoint("BOTTOMRIGHT",f,col==1 and "BOTTOMLEFT" or "BOTTOMRIGHT",col==1 and endWidth or right,bottom)
                if row==1 then t:SetHeight(edgeHeight) t:ClearAllPoints()
                    t:SetPoint("TOPLEFT",f,col==3 and "TOPRIGHT" or "TOPLEFT",col==3 and -endWidth or left,0)
                    t:SetPoint("TOPRIGHT",f,col==1 and "TOPLEFT" or "TOPRIGHT",col==1 and endWidth or right,0)
                elseif row==3 then t:SetHeight(edgeHeight) t:ClearAllPoints()
                    t:SetPoint("BOTTOMLEFT",f,col==3 and "BOTTOMRIGHT" or "BOTTOMLEFT",col==3 and -endWidth or left,0)
                    t:SetPoint("BOTTOMRIGHT",f,col==1 and "BOTTOMLEFT" or "BOTTOMRIGHT",col==1 and endWidth or right,0)
                end
            end
        end
    end
    return f
end

-- Keep the sculpted ends at their original aspect ratio. Only the straight
-- metal rails span the variable distance between the ends.
local function createCompactRail(parent, portraitOnRight)
    local rail=CreateFrame("Frame",nil,parent)
    rail:EnableMouse(false)
    rail.fill=parent:CreateTexture(nil,"BACKGROUND",nil,-7)
    rail.fill:SetColorTexture(0,0,0,.94)
    rail:SetScript("OnShow",function() rail.fill:Show() end)
    rail:SetScript("OnHide",function() rail.fill:Hide() end)
    local function piece(u1,u2,v1,v2)
        local texture=rail:CreateTexture(nil,"OVERLAY")
        texture:SetTexture(media.."GulveigRailV2.tga")
        texture:SetTexCoord(u1,u2,v1,v2)
        return texture
    end
    rail.top=piece(.10,.90,.18,.31)
    rail.bottom=piece(.10,.90,.68,.81)
    if portraitOnRight~=false then rail.left=piece(0,.10,.18,.81) end
    if portraitOnRight~=true then rail.right=piece(.90,1,.18,.81) end
    return rail
end

local function fitCompactRail(rail, bar, barHeight, top, bottom)
    local height=barHeight+top+bottom
    local cap=height*(.10*3/.63)
    local edge=height*(.13/.63)
    local left=rail.left and cap*.72 or 2
    local right=rail.right and cap*.72 or 2
    rail:ClearAllPoints()
    rail:SetPoint("TOPLEFT",bar,"TOPLEFT",-left,top)
    rail:SetPoint("BOTTOMRIGHT",bar,"BOTTOMRIGHT",right,-bottom)
    local leftInset=rail.left and cap or 0
    local rightInset=rail.right and cap or 0
    if rail.left then rail.left:SetPoint("LEFT") rail.left:SetSize(cap,height) end
    if rail.right then rail.right:SetPoint("RIGHT") rail.right:SetSize(cap,height) end
    rail.top:SetPoint("TOPLEFT",rail,"TOPLEFT",leftInset,0)
    rail.top:SetPoint("TOPRIGHT",rail,"TOPRIGHT",-rightInset,0)
    rail.top:SetHeight(edge)
    rail.bottom:SetPoint("BOTTOMLEFT",rail,"BOTTOMLEFT",leftInset,0)
    rail.bottom:SetPoint("BOTTOMRIGHT",rail,"BOTTOMRIGHT",-rightInset,0)
    rail.bottom:SetHeight(edge)
    rail.fill:SetPoint("TOPLEFT",rail,"TOPLEFT",leftInset*.65,-edge*.66)
    rail.fill:SetPoint("BOTTOMRIGHT",rail,"BOTTOMRIGHT",-rightInset*.65,edge*.66)
end

local function barRegion(frame)
    local content=frame.PlayerFrameContent or frame.TargetFrameContent
    local main=content and (content.PlayerFrameContentMain or content.Main)
    local name=frame.GetName and frame:GetName()
    return frame.healthbar or frame.HealthBar or (main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar)
        or (name and (_G[name.."HealthBar"] or _G[name.."Healthbar"]))
end
local function rect(region,parent)
    if not region or not region.GetRect then return end
    local x,y,w,h=region:GetRect()
    if not usableNumber(x) or not usableNumber(y) or not usableNumber(w) or not usableNumber(h) or w<=0 or h<=0 then return end
    local scale,parentScale=region:GetEffectiveScale(),parent:GetEffectiveScale()
    if not usableNumber(scale) or not usableNumber(parentScale) or parentScale<=0 then return end
    local s=scale/parentScale
    return x*s,y*s,w*s,h*s
end

local auraRows={}
local auraFilters={"HELPFUL","HARMFUL"}

local function updateAuraRow(row)
    local getAura=C_UnitAuras.GetAuraDataByIndex
    local accessDenied=false
    for i,icon in ipairs(row.icons) do
        local texture
        if not accessDenied then
            -- The client can reject the query itself before returning aura data.
            local ok,aura=pcall(getAura,row.unit,1,auraFilters[i])
            accessDenied=not ok
            if ok and readable(aura) and aura then texture=aura.icon end
        end
        if readable(texture) and texture then
            icon:SetTexture(texture)
            icon:Show()
        else
            icon:Hide()
        end
    end
end

local function showAuraRow(art,frame,bar,unit,mirror,compact,show)
    local row=art.auras
    if show and not row then
        row=CreateFrame("Frame",nil,frame)
        row.unit,row.icons=unit,{}
        row:SetSize(compact and 30 or 42,compact and 13 or 18)
        row:SetPoint(mirror and "TOPRIGHT" or "TOPLEFT",bar,mirror and "BOTTOMRIGHT" or "BOTTOMLEFT",0,-(compact and 3 or 5))
        for i=1,2 do
            local icon=row:CreateTexture(nil,"ARTWORK")
            icon:SetSize(compact and 13 or 18,compact and 13 or 18)
            icon:SetPoint("LEFT",row,"LEFT",(i-1)*(compact and 16 or 21),0)
            row.icons[i]=icon
        end
        row:SetScript("OnShow",updateAuraRow)
        art.auras=row
    end
    auraRows[unit]=show and row or nil
    if row then
        row:SetShown(not not show)
        if show and row:IsVisible() then updateAuraRow(row) end
    end
end

SD:On("UNIT_AURA",function(unit)
    local row=auraRows[unit]
    if row and row:IsVisible() then updateAuraRow(row) end
end)
local function updateChangedUnit(unit)
    local row=auraRows[unit]
    if row and row:IsVisible() then updateAuraRow(row) end
end
SD:On("PLAYER_TARGET_CHANGED",function() updateChangedUnit("target") updateChangedUnit("targettarget") end)
SD:On("PLAYER_FOCUS_CHANGED",function() updateChangedUnit("focus") end)
SD:On("UNIT_TARGET",function(unit) if unit=="target" then updateChangedUnit("targettarget") end end)
SD:On("UNIT_PET",function(unit) if unit=="player" then updateChangedUnit("pet") end end)

function SD:RefreshOrnamentalFrames(active)
    self:RefreshTofuUnitArt(active,barRegion,rect)
    local show=active and self.layoutName=="Gulveig Bar" and self.db.stoneUnits
    for _,entry in ipairs({
        {PlayerFrame,false,"PlayerPortrait","player"},
        {TargetFrame,true,"TargetFramePortrait","target"},
        {FocusFrame,true,"FocusFramePortrait","focus",true},
        {PetFrame,false,"PetPortrait","pet",true},
        {TargetFrameToT or (TargetFrame and (TargetFrame.totFrame or TargetFrame.ToT)),true,"TargetFrameToTPortrait","targettarget",true},
    }) do
        local frame,mirror,unit,compact=entry[1],entry[2],entry[4],entry[5]
        if frame then
            local container=frame.PlayerFrameContainer or frame.TargetFrameContainer
            local portrait=frame.portrait or frame.Portrait or (container and container.Portrait) or _G[entry[3]]
            local bar=barRegion(frame)
            local width=show and portrait and portrait.GetWidth and portrait:GetWidth()
            local height=show and bar and bar.GetHeight and bar:GetHeight()
            local fitted=usableNumber(width) and width>0 and usableNumber(height) and height>0
            local art=unitArt[frame]
            if fitted and not art then
                art={ring=frame:CreateTexture(nil,"OVERLAY",nil,6),border=createCompactRail(frame,mirror)}
                art.ring:SetTexture(media.."GulveigPortraitV2.tga")
                art.ring:SetVertexColor(1,.88,.72)
                unitArt[frame]=art frame.stoneDockTrim=art
            end
            local nativeTexture=(container and (container.FrameTexture or container.Texture)) or (frame.GetName and _G[(frame:GetName() or "").."Texture"])
            suppress(nativeTexture,fitted)
            if art then
                art.ring:SetShown(not not fitted) art.border:SetShown(not not fitted)
                if fitted then
                    -- Measured alpha opening, not the full bitmap canvas: center .562/.489, diameter .618/.633.
                    local d=width
                    local w,h=d/.618,d/.633
                    art.ring:SetSize(w,h) art.ring:ClearAllPoints()
                    art.ring:SetTexCoord(mirror and 1 or 0,mirror and 0 or 1,0,1)
                    art.ring:SetPoint("CENTER",portrait,"CENTER",(mirror and 1 or -1)*w*.062,-h*.011)
                    local _,by,_,bh=rect(bar,frame)
                    local top,bottom=height*.85,height*.5
                    if by then
                        local power=frame.manabar or frame.ManaBar or frame.powerBar
                        local name=frame.name or frame.Name or (frame.GetName and _G[(frame:GetName() or "").."Name"])
                        local _,ny,_,nh=rect(name,frame)
                        local _,py=rect(power,frame)
                        if ny then top=math.max(2,ny+nh-by-bh+5) end
                        if py then bottom=math.max(2,by-py+4) end
                    end
                    fitCompactRail(art.border,bar,height,top,bottom)
                end
                showAuraRow(art,frame,art.border,unit,mirror,compact,
                    fitted and self.db.attachPlayerAuras and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex)
            end
            local cast=frame.spellbar or frame.CastBar
            if cast then self:StyleGulveigCast(cast,show) end
        end
    end
    for _,cast in pairs({PlayerCastingBarFrame,CastingBarFrame,PetCastingBarFrame}) do self:StyleGulveigCast(cast,show) end
end

function SD:RefreshGulveigTrackingArt(show)
    for _,bar in pairs({MainStatusTrackingBarContainer,SecondaryStatusTrackingBarContainer}) do
        local nativeBorder=bar.BarFrameTexture
        if nativeBorder then
            local trim=bar.stoneDockTrackingTrim
            if show and not trim then
                trim=self:CreateGulveigBorder(bar,16,3)
                trim:SetPoint("TOPLEFT",nativeBorder,"TOPLEFT",-13,2)
                trim:SetPoint("BOTTOMRIGHT",nativeBorder,"BOTTOMRIGHT",13,-2)
                bar.stoneDockTrackingTrim=trim
            end
            if trim then
                trim:SetShown(show)
                suppress(nativeBorder,show)
            end
        end
    end
end

function SD:StyleGulveigCast(cast,show)
    if not cast then return end
    local height=show and cast:GetHeight()
    show=usableNumber(height) and height>0
    local art=castArt[cast]
    if show and not art then
        art=createCompactRail(cast) castArt[cast]=art cast.stoneDockCastTrim=art
    end
    if art then
        if show then fitCompactRail(art,cast,height,2,2) end
        art:SetShown(not not show)
    end
    suppress(cast.Border or cast.border,show)
end

local function label(parent,size)
    local text=parent:CreateFontString(nil,"OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF",size,"")
    text:SetTextColor(.91,.83,.59)
    text:SetShadowOffset(1,-1)
    return text
end

function SD:UpdateMapCaption()
    if not self.mapCaption or not self.mapCaption:IsShown() then return end
    self.mapCaption.zone:SetText((GetMinimapZoneText and GetMinimapZoneText()) or GetZoneText())
    local hour,minute
    if GetGameTime then hour,minute=GetGameTime() end
    self.mapCaption.clock:SetText(hour and string.format("%02d:%02d",hour,minute) or date("%H:%M"))
end

function SD:RefreshMapTheme()
    local active=self.db.enabled and self.layoutName~="Tofu Bar" and self:IsOurLayoutActive()
    if not Minimap then return end
    local mapWidth,mapHeight=Minimap:GetWidth(),Minimap:GetHeight()
    if not usableNumber(mapWidth) or not usableNumber(mapHeight) or mapWidth<=0 or mapHeight<=0 then return end
    if not self.mapThemeSizeHooked and Minimap.HookScript then
        self.mapThemeSizeHooked=true
        Minimap:HookScript("OnSizeChanged",function() SD:RefreshMapTheme() end)
    end
    if not self.mapCaption then
        local f=CreateFrame("Frame",nil,MinimapCluster or Minimap,"BackdropTemplate") self.mapCaption=f
        f:EnableMouse(false)
        f:SetSize(180,32) f:SetPoint("TOP",Minimap,"BOTTOM",0,-31)
        f.zone=label(f,12) f.zone:SetPoint("TOP",f,"TOP",0,-3) f.zone:SetWidth(170)
        f.clock=label(f,11) f.clock:SetPoint("BOTTOM",f,"BOTTOM",0,3)
        f.trim=f:CreateTexture(nil,"BORDER") f.trim:SetAllPoints()
        self.mapRim=Minimap:CreateTexture(nil,"OVERLAY",nil,6)
        self.mapRim:SetTexture(media.."GulveigMapV2.tga")
        self.mapRim:SetPoint("TOPLEFT",Minimap,"TOPLEFT",-mapWidth*.125,mapHeight*.125)
        self.mapRim:SetPoint("BOTTOMRIGHT",Minimap,"BOTTOMRIGHT",mapWidth*.125,-mapHeight*.125)
    end
    local gulveig=self.layoutName=="Gulveig Bar"
    self.mapRim:ClearAllPoints()
    self.mapRim:SetPoint("TOPLEFT",Minimap,"TOPLEFT",-mapWidth*.125,mapHeight*.125)
    self.mapRim:SetPoint("BOTTOMRIGHT",Minimap,"BOTTOMRIGHT",mapWidth*.125,-mapHeight*.125)
    self.mapRim:SetVertexColor(1,.94,.80)
    if not self.mapCaption.border then
        self.mapCaption.border=self:CreateGulveigBorder(self.mapCaption)
        self.mapCaption.border:SetPoint("TOPLEFT",self.mapCaption,"TOPLEFT",-4,6)
        self.mapCaption.border:SetPoint("BOTTOMRIGHT",self.mapCaption,"BOTTOMRIGHT",4,-6)
    end
    if not self.gulveigZonePlate then
        local plate=CreateFrame("Frame",nil,self.mapCaption)
        plate:EnableMouse(false)
        plate:SetPoint("BOTTOM",Minimap,"TOP",0,mapHeight*.12+4)
        plate:SetHeight(19)
        plate.border=self:CreateGulveigBorder(plate,10,4)
        plate.border:SetAllPoints()
        self.gulveigZonePlate=plate
        self.mapNorth=label(Minimap,12)
        self.mapNorth:SetPoint("TOP",Minimap,"TOP",0,5)
    end
    self.gulveigZonePlate:ClearAllPoints()
    self.gulveigZonePlate:SetPoint("BOTTOM",Minimap,"TOP",0,mapHeight*.12+4)
    self.gulveigZonePlate:SetWidth(math.max(120,mapWidth*.85))
    self.gulveigZonePlate:SetShown(active and gulveig)
    self.mapNorth:SetText("N")
    self.mapNorth:SetShown(active and gulveig and not (GetCVarBool and GetCVarBool("rotateMinimap")))
    self.mapCaption.zone:ClearAllPoints()
    if gulveig then
        self.mapCaption.zone:SetPoint("CENTER",self.gulveigZonePlate,"CENTER")
    else
        self.mapCaption.zone:SetPoint("TOP",self.mapCaption,"TOP",0,-3)
    end
    self.mapCaption.border:SetShown(active and gulveig)
    self.mapCaption:SetShown(active)
    self.mapRim:SetShown(active and gulveig)
    self.mapCaption:ClearAllPoints()
    local mapPanel=self.panels and self.panels.map
    if gulveig or not mapPanel then
        self.mapCaption:SetHeight(gulveig and 17 or 32)
        self.mapCaption:SetPoint("TOP",Minimap,"BOTTOM",0,-(mapHeight*.112+4))
    else
        -- The dashboard map sits at the screen edge. Keep both labels inside its panel.
        self.mapCaption:SetHeight(25)
        self.mapCaption:SetPoint("BOTTOM",mapPanel,"BOTTOM",0,4)
    end
    self.mapCaption:SetWidth(gulveig and 78 or math.max(140,mapWidth*.9))
    self.mapCaption.zone:SetWidth(math.max(130,mapWidth*.9-18))
    self.mapCaption:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    self.mapCaption:SetBackdropColor(0,0,0,gulveig and 0 or .95)
    local color=self.colors[self.db.accent]
    self.mapCaption:SetBackdropBorderColor(color[1],color[2],color[3],gulveig and 0 or 1)
    self.mapCaption.trim:SetTexture(gulveig and media.."GulveigChat.tga" or media.."Shade.tga")
    self.mapCaption.trim:SetShown(false)
    -- Hide only duplicate native label text; native minimap controls stay intact.
    self.mapLabelAlphas=self.mapLabelAlphas or {}
    local cluster=MinimapCluster
    local container=cluster and cluster.MinimapContainer
    local hidden={MinimapZoneText,TimeManagerClockTicker,TimeManagerClockButton,
        cluster and cluster.ZoneTextButton,container and container.PlayerCoords}
    if gulveig then hidden.rim=MinimapCompassTexture hidden.legacyRim=MinimapBorder end
    if not gulveig then
        for _,rim in pairs({MinimapCompassTexture,MinimapBorder}) do
            if self.mapLabelAlphas[rim]~=nil then rim:SetAlpha(self.mapLabelAlphas[rim]) self.mapLabelAlphas[rim]=nil end
        end
    end
    for _,region in pairs(hidden) do
        if region and region.GetAlpha then
            if active then
                if self.mapLabelAlphas[region]==nil then self.mapLabelAlphas[region]=region:GetAlpha() end
                region:SetAlpha(0)
            elseif self.mapLabelAlphas[region]~=nil then region:SetAlpha(self.mapLabelAlphas[region]) self.mapLabelAlphas[region]=nil end
        end
    end
    if active and not self.mapCaptionTicker then
        self.mapCaptionTicker=C_Timer.NewTicker(30,function()SD:UpdateMapCaption()end)
    elseif not active and self.mapCaptionTicker then self.mapCaptionTicker:Cancel() self.mapCaptionTicker=nil end
    self:UpdateMapCaption()
end
