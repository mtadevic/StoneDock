local _, SD = ...
local borders=setmetatable({}, {__mode="k"})
local pending
function SD:SetSoftBarBorder(button,show)
    if not button or not button.CreateTexture then return end
    local border=borders[button]
    if show and not border then
        if InCombatLockdown() then self.softBarArtAfterCombat=true return end
        border={}
        -- Thin outside-only rings: no texture spans the button or fills its center.
        for pad,alpha in ipairs({.34,.22,.12,.055,.015}) do
            for side=1,4 do
                local edge=button:CreateTexture(nil,"BACKGROUND",nil,-8)
                edge:SetTexture("Interface\\Buttons\\WHITE8X8") edge:SetVertexColor(0,0,0,alpha)
                if side==1 or side==2 then
                    local anchor=side==1 and "TOP" or "BOTTOM"
                    local y=side==1 and pad or -pad
                    edge:SetPoint(anchor.."LEFT",button,anchor.."LEFT",-pad,y)
                    edge:SetPoint(anchor.."RIGHT",button,anchor.."RIGHT",pad,y)
                    edge:SetHeight(1)
                else
                    local anchor=side==3 and "LEFT" or "RIGHT"
                    local x=side==3 and -pad or pad
                    edge:SetPoint("TOP"..anchor,button,"TOP"..anchor,x,pad-1)
                    edge:SetPoint("BOTTOM"..anchor,button,"BOTTOM"..anchor,x,-pad+1)
                    edge:SetWidth(1)
                end
                border[#border+1]=edge
            end
        end
        borders[button]=border
    end
    if border then for _,edge in ipairs(border) do edge:SetShown(not not show) end end
end
-- Skin only the native decorative frame; preserve checked, hover, proc and cooldown regions.
local nativeArt=setmetatable({}, {__mode="k"})
function SD:SkinNativeBarButton(button,show)
    if InCombatLockdown() then self.softBarArtAfterCombat=true return end
    local state=nativeArt[button]
    if not state and not show then return end
    if not state then
        state={regions={}} nativeArt[button]=state
        local media="Interface\\AddOns\\StoneDock\\Media\\"
        state.seat=button:CreateTexture(nil,"BACKGROUND",nil,-8)
        state.seat:SetTexture(media.."AdeptButtonSeat.tga")
        state.bezel=button:CreateTexture(nil,"ARTWORK",nil,2)
        state.bezel:SetTexture(media.."AdeptButtonBezel.tga")
        for _,region in ipairs({state.seat,state.bezel}) do
            region:SetPoint("TOPLEFT",button,"TOPLEFT",-4,4)
            region:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",4,-4)
        end
        local function changed()
            if state.active then SD:SkinNativeBarButton(button,true) end
        end
        for _,method in ipairs({"SetNormalTexture","SetNormalAtlas"}) do
            if button[method] and hooksecurefunc then hooksecurefunc(button,method,changed) end
        end
    end
    state.active=show
    state.seat:SetShown(not not show) state.bezel:SetShown(not not show)
    local name=button.GetName and button:GetName()
    local icon=button.icon or button.Icon or (name and _G[name.."Icon"])
    if show and icon and icon.AddMaskTexture and button.CreateMaskTexture then
        if not state.mask then
            state.mask=button:CreateMaskTexture(nil,"ARTWORK")
            state.mask:SetTexture("Interface\\AddOns\\StoneDock\\Media\\AdeptButtonMask.tga")
        end
        if state.icon~=icon then
            if state.icon and state.icon.RemoveMaskTexture then state.icon:RemoveMaskTexture(state.mask) end
            icon:AddMaskTexture(state.mask) state.icon=icon
        end
        state.mask:ClearAllPoints() state.mask:SetAllPoints(icon)
    elseif not show and state.icon then
        if state.icon.RemoveMaskTexture then state.icon:RemoveMaskTexture(state.mask) end
        state.icon=nil
    end
    if show then
        local function suppress(region)
            if not region or not region.SetAlpha then return end
            if state.regions[region]==nil then state.regions[region]=region:GetAlpha() end
            region:SetAlpha(0)
        end
        suppress(button.GetNormalTexture and button:GetNormalTexture())
        suppress(button.NormalTexture) suppress(button.NormalTexture2) suppress(button.SlotArt) suppress(button.SlotBackground)
        local name=button.GetName and button:GetName()
        if name then suppress(_G[name.."NormalTexture"]) suppress(_G[name.."NormalTexture2"]) end
    else
        for region,alpha in pairs(state.regions) do region:SetAlpha(alpha) end
        state.regions={}
    end
end
function SD:FitItemCooldown(button)
    local cooldown=button and button.cooldown
    if not cooldown then return end
    if cooldown.GetCountdownFontString then
        local font=cooldown:GetCountdownFontString()
        if font then
            font:SetFont("Fonts\\ARIALN.TTF",math.max(6,math.min(10,button:GetWidth()*.45)),"OUTLINE")
            font:SetWordWrap(false) font:ClearAllPoints() font:SetPoint("CENTER",button,"CENTER",0,0)
        end
    end

end
function SD:RefreshSoftBarBorders()
    if InCombatLockdown() then self.softBarArtAfterCombat=true return end
    self.softBarArtAfterCombat=nil
    local show=self.db and self.db.enabled and self.layoutName=="Adept" and self:IsOurLayoutActive() and not self.editing
    local wanted={}
    for _,name in ipairs({"MainActionBar","MultiBarBottomLeft","MultiBarBottomRight","MultiBarRight","MultiBarLeft",
        "MultiBar5","MultiBar6","MultiBar7","StanceBar","PetActionBar","PossessActionBar"}) do
        local bar=_G[name]
        for _,button in ipairs(bar and bar.actionButtons or {}) do wanted[button]=true self:SetSoftBarBorder(button,false) self:SkinNativeBarButton(button,show) end
    end
    for _,prefix in ipairs({"ActionButton","MultiBarBottomLeftButton","MultiBarBottomRightButton","MultiBarRightButton","MultiBarLeftButton",
        "MultiBar5Button","MultiBar6Button","MultiBar7Button","PetActionButton","StanceButton","PossessButton"}) do
        for i=1,12 do local button=_G[prefix..i] if button then wanted[button]=true self:SetSoftBarBorder(button,false) self:SkinNativeBarButton(button,show) end end
    end
    for button in pairs(nativeArt) do
        if not wanted[button] or not show then self:SkinNativeBarButton(button,false) end
    end
    for button in pairs(borders) do
        if not wanted[button] and not button.stoneDockUtilityBorder then self:SetSoftBarBorder(button,false) end
        if not show then self:SetSoftBarBorder(button,false) end
    end
end
local function queue()
    if pending then return end pending=true
    C_Timer.After(0,function()pending=nil if SD.db then SD:RefreshSoftBarBorders() end end)
end
SD:On("PET_BAR_UPDATE",queue)
SD:On("UPDATE_SHAPESHIFT_FORMS",queue)
SD:On("PLAYER_REGEN_ENABLED",function()if SD.softBarArtAfterCombat then queue()end end)

SD:On("ACTIONBAR_SLOT_CHANGED",queue)
