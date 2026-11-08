local _,SD=...
local media="Interface\\AddOns\\StoneDock\\Media\\"
local portraitArt=setmetatable({}, {__mode="k"})
local nativeUnitAlpha=setmetatable({}, {__mode="k"})

local function barRegion(frame)
    local content=frame.PlayerFrameContent or frame.TargetFrameContent
    local main=content and (content.PlayerFrameContentMain or content.Main)
    return frame.healthbar or frame.HealthBar or (main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar)
end

function SD:RefreshOrnamentalFrames(active)
    local show=active and self.layoutName=="Gulveig Bar" and self.db.stoneUnits
    for _,entry in ipairs({{PlayerFrame,false,"PlayerPortrait"},{TargetFrame,true,"TargetFramePortrait"},{FocusFrame,true,"FocusFramePortrait"}}) do
        local frame,mirror=entry[1],entry[2]
        if frame then
            local art=portraitArt[frame]
            if show and not art then
                art={}
                for i=1,2 do
                    art[i]=frame:CreateTexture(nil,"OVERLAY",nil,6)
                    art[i]:SetTexture(media.."GulveigUnit.tga")
                end
                art.backing=frame:CreateTexture(nil,"BACKGROUND",nil,-7)
                art.backing:SetColorTexture(0,0,0,.9)
                portraitArt[frame]=art
            end
            if art then
                local container=frame.PlayerFrameContainer or frame.TargetFrameContainer
                local portrait=frame.portrait or frame.Portrait or (container and container.Portrait) or _G[entry[3]]
                local bar=barRegion(frame)
                local nativeTexture=(container and (container.FrameTexture or container.Texture)) or (frame.GetName and _G[(frame:GetName() or "").."Texture"])
                if nativeTexture and nativeTexture.GetAlpha then
                    if show and portrait and bar then
                        if nativeUnitAlpha[nativeTexture]==nil then nativeUnitAlpha[nativeTexture]=nativeTexture:GetAlpha() end
                        nativeTexture:SetAlpha(0)
                    elseif nativeUnitAlpha[nativeTexture]~=nil then
                        nativeTexture:SetAlpha(nativeUnitAlpha[nativeTexture]) nativeUnitAlpha[nativeTexture]=nil
                    end
                end
                -- Each opening follows its own native region. Never guess a whole-frame aspect ratio.
                local fitted=show and portrait and bar and portrait.GetWidth and bar.GetWidth
                for _,t in pairs(art) do t:SetShown(not not fitted) t:ClearAllPoints() end
                if fitted then
                    art.backing:SetPoint("TOPLEFT",bar,"TOPLEFT",-2,17)
                    art.backing:SetPoint("BOTTOMRIGHT",bar,"BOTTOMRIGHT",2,-10)
                    local diameter=portrait:GetWidth()
                    local ring=art[1]
                    ring:SetSize(diameter*1.42,diameter*1.42)
                    ring:SetTexCoord(mirror and .33 or 0,mirror and 0 or .33,0,1)
                    ring:SetPoint("CENTER",portrait,"CENTER",(mirror and 1 or -1)*diameter*.13,diameter*.04)
                    local rails=art[2]
                    rails:SetTexCoord(mirror and 1 or .33,mirror and .33 or 1,.15,.80)
                    rails:SetPoint("TOPLEFT",bar,"TOPLEFT",-4,19)
                    rails:SetPoint("BOTTOMRIGHT",bar,"BOTTOMRIGHT",4,-12)
                end
            end
        end
    end
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
    local active=self.db.enabled and self:IsOurLayoutActive()
    if not Minimap then return end
    if not self.mapCaption then
        local f=CreateFrame("Frame",nil,MinimapCluster or Minimap,"BackdropTemplate") self.mapCaption=f
        f:EnableMouse(false)
        f:SetSize(180,42) f:SetPoint("TOP",Minimap,"BOTTOM",0,-16)
        f.zone=label(f,12) f.zone:SetPoint("TOP",f,"TOP",0,-3) f.zone:SetWidth(170)
        f.clock=label(f,11) f.clock:SetPoint("BOTTOM",f,"BOTTOM",0,3)
        f.trim=f:CreateTexture(nil,"BORDER") f.trim:SetAllPoints()
        self.mapRim=Minimap:CreateTexture(nil,"OVERLAY",nil,6)
        self.mapRim:SetTexture(media.."GulveigMap.tga")
        self.mapRim:SetPoint("TOPLEFT",Minimap,"TOPLEFT",-12,12)
        self.mapRim:SetPoint("BOTTOMRIGHT",Minimap,"BOTTOMRIGHT",12,-12)
    end
    local gulveig=self.layoutName=="Gulveig Bar"
    self.mapCaption:SetShown(active)
    self.mapRim:SetShown(active and gulveig)
    self.mapCaption:SetWidth(math.max(140,Minimap:GetWidth()*.9))
    self.mapCaption.zone:SetWidth(math.max(130,Minimap:GetWidth()*.9-18))
    self.mapCaption:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    self.mapCaption:SetBackdropColor(0,0,0,.95)
    local color=self.colors[self.db.accent]
    self.mapCaption:SetBackdropBorderColor(color[1],color[2],color[3],1)
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
