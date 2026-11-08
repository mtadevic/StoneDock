local _, SD = ...
-- Item IDs only; catalog reference: awls99/Random-Hearthstone-Toy-Continued,
-- AllHearthToyIndex_en.lua. Names, icons and usability come from the client.
local catalog={6948,110560,140192,166747,165802,165670,165669,166746,163045,162973,142542,64488,54452,93672,168907,172179,182773,180290,184353,183716,188952,190237,193588,190196,200630,206195,209035,208704,212337,228940,236687,235016,245970,246565,263489,263933,257736,281136,281615,265100}
local function safe(v) return not issecretvalue or not issecretvalue(v) end
local rejected={[118427]=true}
local function hearthName(name)
    if not name or not safe(name) then return false end
    local value=name:lower()
    if value:find("card",1,true) or value:find("deck",1,true) or value:find("hearthstone board",1,true) then return false end
    return value:find("hearthstone",1,true) or value:find("town portal",1,true)
end
function SD:ScanHearthstones()
    if InCombatLockdown() then return end
    if not C_Item or not C_Item.GetItemInfo then return end
    local candidates,owned={},{}
    for _,id in ipairs(catalog) do candidates[id]=true end
    for id in pairs(self.db.hearthDiscovered) do candidates[id]=true end
    -- Discover new hearth-named toys visible in the journal without touching
    -- the user's search, ownership, expansion or source filters.
    if C_ToyBox and C_ToyBox.GetNumFilteredToys and C_ToyBox.GetToyFromIndex then
        for i=1,C_ToyBox.GetNumFilteredToys() do
            local id=C_ToyBox.GetToyFromIndex(i)
            if id and PlayerHasToy and PlayerHasToy(id) then
                local _,name=C_ToyBox.GetToyInfo(id)
                if hearthName(name) then candidates[id]=true self.db.hearthDiscovered[id]=true end
            end
        end
    end
    if C_Container and C_Container.GetContainerItemInfo then
        for bag=0,NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 do
            for slot=1,C_Container.GetContainerNumSlots(bag) do
                local info=C_Container.GetContainerItemInfo(bag,slot)
                local id=info and info.itemID
                if id and safe(id) then
                    local name=C_Item.GetItemInfo(id)
                    if hearthName(name) then candidates[id]=true end
                end
            end
        end
    end
    for id in pairs(candidates) do
        local isToy=PlayerHasToy and PlayerHasToy(id)
        local hasItem=C_Item.GetItemCount and C_Item.GetItemCount(id,false)>0
        if not rejected[id] and (isToy or hasItem) then
            local name,_,_,_,_,_,_,_,_,icon=C_Item.GetItemInfo(id)
            if not name and isToy and C_ToyBox and C_ToyBox.GetToyInfo then local _; _,name,icon=C_ToyBox.GetToyInfo(id) end
            if name then
                local usable=true
                if isToy and C_ToyBox and C_ToyBox.IsToyUsable then usable=C_ToyBox.IsToyUsable(id)==true
                elseif C_Item.IsUsableItem then usable=C_Item.IsUsableItem(id)==true end
                owned[#owned+1]={id=id,name=name,icon=icon,toy=isToy,usable=usable,home=id~=110560 and id~=140192}
            elseif C_Item.RequestLoadItemDataByID then self:RequestItemData(id) end
        end
    end
    table.sort(owned,function(a,b) if a.id==6948 then return true elseif b.id==6948 then return false end return a.name<b.name end)
    self.hearthstones=owned
end
function SD:CreateHearthButton()
    if self.hearthButton or not self.utilityRoot or InCombatLockdown() then return end
    local b=CreateFrame("Button","StoneDockHearth",self.utilityRoot,"SecureActionButtonTemplate") self.hearthButton=b
    b.hearth=true b.label="Hearthstones" b:SetSize(24,24) b:RegisterForClicks("AnyUp","AnyDown")
    b.icon=b:CreateTexture(nil,"ARTWORK") b.icon:SetAllPoints() b.icon:SetTexture(134414)
    b.border=b:CreateTexture(nil,"BACKGROUND") b.border:SetPoint("TOPLEFT",-1,1) b.border:SetPoint("BOTTOMRIGHT",1,-1) b.border:SetColorTexture(.4,.45,.5,1)
    b.count=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall") b.count:SetPoint("BOTTOMRIGHT")
    b.cooldown=CreateFrame("Cooldown",nil,b,"CooldownFrameTemplate") b.cooldown:SetAllPoints()
    b:SetScript("OnEnter",function()
        GameTooltip:SetOwner(b,"ANCHOR_TOP")
        if b.itemID and GameTooltip.SetItemByID then GameTooltip:SetItemByID(b.itemID) else GameTooltip:AddLine("Hearthstones") end
        GameTooltip:AddLine("Left-click: selected hearth. Right-click: travel menu.",.65,.75,.85,true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    b:HookScript("OnClick",function(_,button,down) if button=="RightButton" and not down then SD:Run("Hearthstone menu",function() SD:ShowUtilityFlyout(b,"hearth") end) end end)
    self.utilityButtons[#self.utilityButtons+1]=b
end
function SD:RefreshHearthButton(scan)
    if InCombatLockdown() or not self.hearthButton then return end
    if scan or not self.hearthstones then self:ScanHearthstones() end
    local chosen
    for _,entry in ipairs(self.hearthstones or {}) do
        if entry.id==(self.db.preferredHearth or 6948) then chosen=entry break end
    end
    if not chosen and not self.db.preferredHearth then
        for _,entry in ipairs(self.hearthstones or {}) do if entry.home and entry.usable and self:GetItemRule("hearth",entry.id)~=false then chosen=entry break end end
    end
    local b=self.hearthButton
    b.hasAvailable=false
    for _,entry in ipairs(self.hearthstones or {}) do if entry.usable and self:GetItemRule("hearth",entry.id)~=false then b.hasAvailable=true break end end
    b.itemID=chosen and chosen.id
    b:SetAttribute("type1",chosen and chosen.usable and self:GetItemRule("hearth",chosen.id)~=false and (chosen.toy and "toy" or "item") or nil)
    b:SetAttribute("item1",chosen and ("item:"..chosen.id) or nil)
    b:SetAttribute("toy1",chosen and chosen.id or nil)
    b.icon:SetTexture(chosen and chosen.icon or 134414)
    b.icon:SetDesaturated(not chosen or not chosen.usable)
end
SD:On("ZONE_CHANGED_NEW_AREA",function() if SD.db then SD:QueueConsumables() end end)
SD:On("NEW_TOY_ADDED",function() if SD.db then SD:QueueConsumables() end end)
