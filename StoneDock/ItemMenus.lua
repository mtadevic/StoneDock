local _, SD = ...

function SD:GetItemRule(key,id)
    local rules=self.db.itemRules or {}
    local spec=rules[self.itemSpec or self:GetConsumableSpec()] or {}
    return spec[key] and spec[key][id]
end
function SD:SetItemRule(key,id,value)
    if InCombatLockdown() then return end
    local spec=self.itemSpec or self:GetConsumableSpec()
    self.db.itemRules=self.db.itemRules or {}
    self.db.itemRules[spec]=self.db.itemRules[spec] or {}
    self.db.itemRules[spec][key]=self.db.itemRules[spec][key] or {}
    self.db.itemRules[spec][key][id]=value
    if value==false then
        if key=='hearth' and self.db.preferredHearth==id then self.db.preferredHearth=nil end
        local pins=self.db.itemOverrides[spec]
        if pins and pins[key]==id then pins[key]=nil end
    end
end
function SD:GetUtilityChoices(key)
    local result,seen={},{}
    local function add(item)
        if item and not seen[item.id] and self:GetItemRule(key,item.id)~=false then
            result[#result+1]=item seen[item.id]=true
        end
    end
    if key=='hearth' then
        for _,item in ipairs(self.hearthstones or {}) do if item.usable then add(item) end end
    elseif key=='trinkets' then
        for slot=13,14 do
            local id=GetInventoryItemID and GetInventoryItemID('player',slot)
            if id then
                local name=C_Item.GetItemInfo(id)
                add({id=id,name=name or ('Trinket '..slot),slot=slot,icon=GetInventoryItemTexture('player',slot)})
            end
        end
    else
        for _,entry in ipairs(self.consumableLists and self.consumableLists[key] or {}) do add(entry.item) end
        for _,item in ipairs(self.allConsumables or {}) do if self:GetItemRule(key,item.id)==true then add(item) end end
    end
    return result
end

-- The flyout only uses items. It never changes inclusion, exclusions or defaults.
function SD:ShowUtilityFlyout(owner,key)
    if InCombatLockdown() then SD.Print('Open item choices after combat.') return end
    if self.itemFlyout then
        local same=self.itemFlyout:IsShown() and self.itemFlyout.owner==owner
        self.itemFlyout:Hide()
        if same then return end
    end
    self:ScanConsumables() self:ScanHearthstones()
    local items=self:GetUtilityChoices(key)
    local CreateFrame,H=self:WindowBuilder('itemFlyout')
    local f=CreateFrame('Frame',nil,UIParent,'BackdropTemplate,SecureHandlerStateTemplate') self.itemFlyout=f
    if RegisterStateDriver and not f.combatDriverRegistered then
        f:SetAttribute('_onstate-stonedockcombat', [[
            if newstate == "combat" then self:Hide() end
        ]])
        RegisterStateDriver(f,'stonedockcombat','[combat] combat; idle')
        f.combatDriverRegistered=true
    end
    f.owner=owner
    f:SetFrameStrata('DIALOG') f:SetClampedToScreen(true)
    f:SetPoint('BOTTOMLEFT',owner,'TOPLEFT',0,8)
    local columns=math.min(6,math.max(1,#items))
    local rows=math.max(1,math.ceil(#items/6))
    local width=columns*36+16
    f:SetSize(width,math.min(6,rows)*36+16)
    f:SetBackdrop({bgFile='Interface\\AddOns\\StoneDock\\Media\\Stone.tga',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',tile=true,tileSize=256,edgeSize=12})
    local child=f
    local insetX,insetY=8,-8
    if rows>6 then
        f:SetWidth(width+18)
        local scroll=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate')
        scroll:SetPoint('TOPLEFT',8,-8)
        scroll:SetSize(columns*36,6*36)
        child=CreateFrame('Frame',nil,scroll)
        child:SetSize(columns*36,rows*36)
        scroll:SetScrollChild(child)
        child:SetPoint('TOPLEFT',scroll,'TOPLEFT')
        scroll:SetVerticalScroll(0)
        insetX,insetY=0,0
    end
    f.buttons={}
    for i,item in ipairs(items) do
        local b=CreateFrame('Button',nil,child,'SecureActionButtonTemplate')
        b:SetPoint('TOPLEFT',child,'TOPLEFT',insetX+((i-1)%6)*36,insetY-math.floor((i-1)/6)*36)
        b:SetSize(32,32)
        b.icon=b.icon or b:CreateTexture(nil,'ARTWORK') b.icon:SetAllPoints() b.icon:SetTexture(item.icon or 134400)
        b.icon:SetTexCoord(.06,.94,.06,.94)
        b.border=b.border or b:CreateTexture(nil,'BACKGROUND') b.border:SetPoint('TOPLEFT',-1,1) b.border:SetPoint('BOTTOMRIGHT',1,-1) b.border:SetColorTexture(.4,.45,.5,1)
        b.cooldown=CreateFrame('Cooldown',nil,b,'CooldownFrameTemplate') b.cooldown:SetAllPoints()
        if C_Item and C_Item.GetItemCooldown then local start,duration=C_Item.GetItemCooldown(item.id) if start and duration then b.cooldown:SetCooldown(start,duration) end end
        b:RegisterForClicks('AnyUp','AnyDown')
        b:SetAttribute('type1',item.toy and 'toy' or 'item')
        b:SetAttribute('toy1',item.id) b:SetAttribute('item1',item.slot and tostring(item.slot) or ('item:'..item.id))
        b:SetScript('OnEnter',function() GameTooltip:SetOwner(b,'ANCHOR_RIGHT') GameTooltip:SetItemByID(item.id) GameTooltip:Show() end)
        b:SetScript('OnLeave',function() GameTooltip:Hide() end)
        b.flyout=f
        if not b.flyoutClickInstalled then
            b.flyoutClickInstalled=true
            b:HookScript('OnClick',function(self,button,down) if button=='LeftButton' and not down and not InCombatLockdown() then self.flyout:Hide() end end)
        end
        f.buttons[i]=b
    end
    if #items==0 then
        f:SetWidth(180)
        H.text(child,'No available items.',12,8,-10,164)
    end
    f:Show()
end
function SD:ShowHearthMenu()
    self:CreateUtilityButtons()
    self:ShowUtilityFlyout(self.hearthButton,'hearth')
    self.hearthMenu=self.itemFlyout
end

function SD:ShowItemPicker(key,label)
    if InCombatLockdown() then SD.Print('Change item settings after combat.') return end
    key=key or 'bufffood'
    self:ScanConsumables() self:ScanHearthstones()
    if self.itemPicker then self.itemPicker:Hide() end
    local CreateFrame,H=self:WindowBuilder('itemPicker')
    local f=CreateFrame('Frame',nil,UIParent,'BackdropTemplate') self.itemPicker=f
    f:SetSize(650,600) f:SetPoint('CENTER') f:SetFrameStrata('DIALOG')
    f:SetBackdrop({bgFile='Interface\\AddOns\\StoneDock\\Media\\Stone.tga',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',tile=true,tileSize=256,edgeSize=14})
    H.text(f,'ITEM SETTINGS - '..(label or key),18,20,-18,610)
    H.text(f,'Default pins the row button. Include adds an item; Exclude removes it. Auto restores category detection. Changes apply to this spec only.',11,20,-48,610)
    local tabs={}
    for _,category in ipairs(self.itemCategories) do tabs[#tabs+1]=category end
    tabs[#tabs+1]={key='hearth',label='Hearthstones'}
    tabs[#tabs+1]={key='trinkets',label='Trinkets'}
    for i,category in ipairs(tabs) do
        H.button(f,category.label,20+((i-1)%3)*205,-85-math.floor((i-1)/3)*32,200,function() SD:ShowItemPicker(category.key,category.label) end)
    end
    H.button(f,'Automatic default',20,-220,610,function()
        if InCombatLockdown() then return end
        if key=='hearth' then SD.db.preferredHearth=nil else
            local spec=SD.itemSpec or SD:GetConsumableSpec()
            SD.db.itemOverrides[spec]=SD.db.itemOverrides[spec] or {} SD.db.itemOverrides[spec][key]=nil
        end
        SD:RefreshUtilityButtons(true)
    end)
    local scroll=CreateFrame('ScrollFrame',nil,f,'UIPanelScrollFrameTemplate') scroll:SetPoint('TOPLEFT',20,-260) scroll:SetSize(610,280)
    local child=CreateFrame('Frame',nil,scroll) scroll:SetScrollChild(child)
    local items=key=='hearth' and (self.hearthstones or {}) or (self.allConsumables or {})
    if key=='trinkets' then
        items={}
        for slot=13,14 do local id=GetInventoryItemID and GetInventoryItemID('player',slot) if id then items[#items+1]={id=id,name=C_Item.GetItemInfo(id) or ('Trinket '..slot)} end end
    end
    child:SetSize(580,math.max(310,#items*58))
    f.rows={}
    for i,item in ipairs(items) do
        local y=-(i-1)*58
        local rule=self:GetItemRule(key,item.id)
        H.text(child,item.name..(rule==false and ' [Excluded]' or rule==true and ' [Included]' or ' [Auto]'),11,0,y,580)
        local function refresh() SD:RefreshUtilityButtons(true) SD:ShowItemPicker(key,label) end
        local row={}
        row.default=H.button(child,'Default',0,y-20,140,function()
            if InCombatLockdown() then return end
            SD:SetItemRule(key,item.id,true)
            if key=='hearth' then SD.db.preferredHearth=item.id else
                local spec=SD.itemSpec or SD:GetConsumableSpec() SD.db.itemOverrides[spec]=SD.db.itemOverrides[spec] or {} SD.db.itemOverrides[spec][key]=item.id
            end
            refresh()
        end)
        row.include=H.button(child,'Include',145,y-20,140,function() if not InCombatLockdown() then SD:SetItemRule(key,item.id,true) refresh() end end)
        row.exclude=H.button(child,'Exclude',290,y-20,140,function() if not InCombatLockdown() then SD:SetItemRule(key,item.id,false) refresh() end end)
        row.auto=H.button(child,'Auto',435,y-20,140,function() if not InCombatLockdown() then SD:SetItemRule(key,item.id,nil) refresh() end end)
        f.rows[i]=row
    end
    H.button(f,'Close settings',20,-552,610,function() SD:CloseSettings() end)
    f:Show()
end

-- Defer until the click has performed its native secure item action.
SD:On("GLOBAL_MOUSE_UP",function(button)
    local f=SD.itemFlyout
    if button=="LeftButton" and f and f:IsShown() and not InCombatLockdown() then
        C_Timer.After(0,function() if not InCombatLockdown() then f:Hide() GameTooltip:Hide() end end)
    end
end)
