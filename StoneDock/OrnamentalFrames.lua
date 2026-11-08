local _,SD=...
local media="Interface\\AddOns\\StoneDock\\Media\\"
local portraitArt=setmetatable({}, {__mode="k"})

function SD:RefreshOrnamentalFrames(active)
    local show=active and self.layoutName=="Gulveig Bar" and self.db.stoneUnits
    for _,entry in ipairs({{PlayerFrame,false,"PlayerPortrait"},{TargetFrame,true,"TargetFramePortrait"},{FocusFrame,true,"FocusFramePortrait"}}) do
        local frame,mirror=entry[1],entry[2]
        if frame then
            local art=portraitArt[frame]
            if show and not art then art=frame:CreateTexture(nil,"OVERLAY",nil,6) art:SetTexture(media.."GulveigUnit.tga") portraitArt[frame]=art end
            if art then
                art:SetShown(not not show)
                if show then
                    local container=frame.PlayerFrameContainer or frame.TargetFrameContainer
                    local portrait=frame.portrait or frame.Portrait or (container and container.Portrait) or _G[entry[3]]
                    art:ClearAllPoints()
                    if portrait and portrait.GetWidth then
                        local diameter=portrait:GetWidth()
                        if diameter<=0 then diameter=64 end
                        local width=diameter*4.2
                        art:SetSize(width,width/3)
                        art:SetPoint("CENTER",portrait,"CENTER",(mirror and -1 or 1)*width*.307,0)
                    else
                        art:SetSize(280,94)
                        art:SetPoint(mirror and "TOPRIGHT" or "TOPLEFT",frame,mirror and "TOPRIGHT" or "TOPLEFT",mirror and 18 or -18,-4)
                    end
                    art:SetTexCoord(mirror and 1 or 0,mirror and 0 or 1,0,1)
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
        f:SetSize(180,36) f:SetPoint("TOP",Minimap,"BOTTOM",0,-5)
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
    self.mapCaption.trim:SetShown(gulveig)
    -- Hide only duplicate native label text; native minimap controls stay intact.
    self.mapLabelAlphas=self.mapLabelAlphas or {}
    for _,region in pairs({MinimapZoneText,TimeManagerClockTicker}) do
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
