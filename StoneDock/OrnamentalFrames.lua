local _,SD=...
local media="Interface\\AddOns\\StoneDock\\Media\\"
local unitArt=setmetatable({}, {__mode="k"})
local castArt=setmetatable({}, {__mode="k"})
local nativeAlpha=setmetatable({}, {__mode="k"})

local function suppress(region,state)
    if not region or not region.GetAlpha then return end
    if state then
        if nativeAlpha[region]==nil then nativeAlpha[region]=region:GetAlpha() end
        region:SetAlpha(0)
    elseif nativeAlpha[region]~=nil then region:SetAlpha(nativeAlpha[region]) nativeAlpha[region]=nil end
end

-- Nine pieces keep the small metal bevels intact as native frames change size.
function SD:CreateGulveigBorder(parent)
    local f=CreateFrame("Frame",nil,parent)
    f:EnableMouse(false)
    f.fill=parent:CreateTexture(nil,"BACKGROUND",nil,-7)
    f:SetScript("OnShow",function() f.fill:Show() end)
    f:SetScript("OnHide",function() f.fill:Hide() end)
    f.fill:SetColorTexture(0,0,0,.92)
    f.fill:SetPoint("TOPLEFT",f,"TOPLEFT",5,-6)
    f.fill:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-5,6)
    local u,v={0,.1,.9,1},{.18,.31,.68,.81}
    for row=1,3 do
        for col=1,3 do
            if row~=2 or col~=2 then
                local t=f:CreateTexture(nil,"OVERLAY",nil,5)
                t:SetTexture(media.."GulveigRailV2.tga")
                t:SetTexCoord(u[col],u[col+1],v[row],v[row+1])
                local left=col==1 and 0 or 6
                local right=col==3 and 0 or -6
                local top=row==1 and 0 or -6
                local bottom=row==3 and 0 or 6
                t:SetPoint("TOPLEFT",f,col==3 and "TOPRIGHT" or "TOPLEFT",col==3 and -6 or left,top)
                t:SetPoint("BOTTOMRIGHT",f,col==1 and "BOTTOMLEFT" or "BOTTOMRIGHT",col==1 and 6 or right,bottom)
                if row==1 then t:SetHeight(6) t:ClearAllPoints()
                    t:SetPoint("TOPLEFT",f,col==3 and "TOPRIGHT" or "TOPLEFT",col==3 and -6 or left,0)
                    t:SetPoint("TOPRIGHT",f,col==1 and "TOPLEFT" or "TOPRIGHT",col==1 and 6 or right,0)
                elseif row==3 then t:SetHeight(6) t:ClearAllPoints()
                    t:SetPoint("BOTTOMLEFT",f,col==3 and "BOTTOMRIGHT" or "BOTTOMLEFT",col==3 and -6 or left,0)
                    t:SetPoint("BOTTOMRIGHT",f,col==1 and "BOTTOMLEFT" or "BOTTOMRIGHT",col==1 and 6 or right,0)
                end
            end
        end
    end
    return f
end

local function barRegion(frame)
    local content=frame.PlayerFrameContent or frame.TargetFrameContent
    local main=content and (content.PlayerFrameContentMain or content.Main)
    return frame.healthbar or frame.HealthBar or (main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar)
end
local function rect(region,parent)
    if not region or not region.GetRect then return end
    local x,y,w,h=region:GetRect()
    if type(x)~="number" or type(y)~="number" or type(w)~="number" or type(h)~="number" or w<=0 or h<=0 then return end
    local s=region:GetEffectiveScale()/parent:GetEffectiveScale()
    return x*s,y*s,w*s,h*s
end

function SD:RefreshOrnamentalFrames(active)
    local show=active and self.layoutName=="Gulveig Bar" and self.db.stoneUnits
    for _,entry in ipairs({{PlayerFrame,false,"PlayerPortrait"},{TargetFrame,true,"TargetFramePortrait"},{FocusFrame,true,"FocusFramePortrait"},{PetFrame,false,"PetPortrait"}}) do
        local frame,mirror=entry[1],entry[2]
        if frame then
            local container=frame.PlayerFrameContainer or frame.TargetFrameContainer
            local portrait=frame.portrait or frame.Portrait or (container and container.Portrait) or _G[entry[3]]
            local bar=barRegion(frame)
            local fitted=show and portrait and bar and portrait.GetWidth and bar.GetWidth
            local art=unitArt[frame]
            if fitted and not art then
                art={ring=frame:CreateTexture(nil,"OVERLAY",nil,6),border=self:CreateGulveigBorder(frame)}
                art.ring:SetTexture(media.."GulveigPortraitV2.tga") unitArt[frame]=art frame.stoneDockTrim=art
            end
            local nativeTexture=(container and (container.FrameTexture or container.Texture)) or (frame.GetName and _G[(frame:GetName() or "").."Texture"])
            suppress(nativeTexture,fitted)
            if art then
                art.ring:SetShown(not not fitted) art.border:SetShown(not not fitted)
                if fitted then
                    -- Measured alpha opening, not the full bitmap canvas: center .562/.489, diameter .618/.633.
                    local d=portrait:GetWidth()+4
                    local w,h=d/.618,d/.633
                    art.ring:SetSize(w,h) art.ring:ClearAllPoints()
                    art.ring:SetTexCoord(mirror and 1 or 0,mirror and 0 or 1,0,1)
                    art.ring:SetPoint("CENTER",portrait,"CENTER",(mirror and 1 or -1)*w*.062,-h*.011)
                    local _,by,_,bh=rect(bar,frame)
                    local top,bottom=20,12
                    if by then
                        local power=frame.manabar or frame.ManaBar or frame.powerBar
                        local name=frame.name or frame.Name or (frame.GetName and _G[(frame:GetName() or "").."Name"])
                        local _,ny,_,nh=rect(name,frame)
                        local _,py=rect(power,frame)
                        if ny then top=math.max(0,ny+nh-(by+bh))+2 end
                        if py then bottom=math.max(0,by-py)+2 end
                    end
                    art.border:ClearAllPoints()
                    art.border:SetPoint("TOPLEFT",bar,"TOPLEFT",-5,top+6)
                    art.border:SetPoint("BOTTOMRIGHT",bar,"BOTTOMRIGHT",5,-bottom-6)
                end
            end
            local cast=frame.spellbar or frame.CastBar
            if cast then self:StyleGulveigCast(cast,show) end
        end
    end
    for _,cast in pairs({PlayerCastingBarFrame,CastingBarFrame,PetCastingBarFrame}) do self:StyleGulveigCast(cast,show) end
end

function SD:StyleGulveigCast(cast,show)
    if not cast then return end
    local art=castArt[cast]
    if show and not art then
        art=self:CreateGulveigBorder(cast) castArt[cast]=art cast.stoneDockCastTrim=art
        art:SetPoint("TOPLEFT",cast,"TOPLEFT",-5,6)
        art:SetPoint("BOTTOMRIGHT",cast,"BOTTOMRIGHT",5,-6)
    end
    if art then art:SetShown(not not show) end
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
    local active=self.db.enabled and self:IsOurLayoutActive()
    if not Minimap then return end
    if not self.mapThemeSizeHooked and Minimap.HookScript then
        self.mapThemeSizeHooked=true
        Minimap:HookScript("OnSizeChanged",function() SD:RefreshMapTheme() end)
    end
    if not self.mapCaption then
        local f=CreateFrame("Frame",nil,MinimapCluster or Minimap,"BackdropTemplate") self.mapCaption=f
        f:EnableMouse(false)
        f:SetSize(180,36) f:SetPoint("TOP",Minimap,"BOTTOM",0,-31)
        f.zone=label(f,12) f.zone:SetPoint("TOP",f,"TOP",0,-3) f.zone:SetWidth(170)
        f.clock=label(f,11) f.clock:SetPoint("BOTTOM",f,"BOTTOM",0,3)
        f.trim=f:CreateTexture(nil,"BORDER") f.trim:SetAllPoints()
        self.mapRim=Minimap:CreateTexture(nil,"OVERLAY",nil,6)
        self.mapRim:SetTexture(media.."GulveigMap.tga")
        self.mapRim:SetPoint("TOPLEFT",Minimap,"TOPLEFT",-Minimap:GetWidth()*.145,Minimap:GetHeight()*.145)
        self.mapRim:SetPoint("BOTTOMRIGHT",Minimap,"BOTTOMRIGHT",Minimap:GetWidth()*.145,-Minimap:GetHeight()*.145)
    end
    local gulveig=self.layoutName=="Gulveig Bar"
    self.mapRim:ClearAllPoints()
    self.mapRim:SetPoint("TOPLEFT",Minimap,"TOPLEFT",-Minimap:GetWidth()*.145,Minimap:GetHeight()*.145)
    self.mapRim:SetPoint("BOTTOMRIGHT",Minimap,"BOTTOMRIGHT",Minimap:GetWidth()*.145,-Minimap:GetHeight()*.145)
    self.mapRim:SetVertexColor(.64,.57,.47)
    if not self.mapCaption.border then
        self.mapCaption.border=self:CreateGulveigBorder(self.mapCaption)
        self.mapCaption.border:SetPoint("TOPLEFT",self.mapCaption,"TOPLEFT",-4,6)
        self.mapCaption.border:SetPoint("BOTTOMRIGHT",self.mapCaption,"BOTTOMRIGHT",4,-6)
    end
    self.mapCaption.border:SetShown(active and gulveig)
    self.mapCaption:SetShown(active)
    self.mapRim:SetShown(active and gulveig)
    self.mapCaption:SetWidth(math.max(140,Minimap:GetWidth()*.9))
    self.mapCaption.zone:SetWidth(math.max(130,Minimap:GetWidth()*.9-18))
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
