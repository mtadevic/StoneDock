local _, SD = ...
local borders=setmetatable({}, {__mode="k"})
local pending
function SD:SetSoftBarBorder(button,show)
    if not button or not button.CreateTexture then return end
    local border=borders[button]
    if show and not border then
        if InCombatLockdown() then self.softBarArtAfterCombat=true return end
        border=button:CreateTexture(nil,"BACKGROUND",nil,-8)
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        if border.SetBlendMode then border:SetBlendMode("BLEND") end
        border:SetVertexColor(0,0,0,.95)
        border:SetPoint("TOPLEFT",button,"TOPLEFT",-7,7)
        border:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",7,-7)
        borders[button]=border
    end
    if border then border:SetShown(not not show) end
end
function SD:RefreshSoftBarBorders()
    if InCombatLockdown() then self.softBarArtAfterCombat=true return end
    self.softBarArtAfterCombat=nil
    local show=self.db and self.db.enabled and self.layoutName=="Adept" and self:IsOurLayoutActive() and not self.editing
    local wanted={}
    for _,name in ipairs({"MainActionBar","MultiBarBottomLeft","MultiBarBottomRight","MultiBarRight","MultiBarLeft",
        "MultiBar5","MultiBar6","MultiBar7","StanceBar","PetActionBar","PossessActionBar"}) do
        local bar=_G[name]
        for _,button in ipairs(bar and bar.actionButtons or {}) do wanted[button]=true self:SetSoftBarBorder(button,show) end
    end
    for _,prefix in ipairs({"ActionButton","MultiBarBottomLeftButton","MultiBarBottomRightButton","MultiBarRightButton","MultiBarLeftButton",
        "MultiBar5Button","MultiBar6Button","MultiBar7Button","PetActionButton","StanceButton","PossessButton"}) do
        for i=1,12 do local button=_G[prefix..i] if button then wanted[button]=true self:SetSoftBarBorder(button,show) end end
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
