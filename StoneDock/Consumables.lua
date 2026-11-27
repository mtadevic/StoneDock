local _, SD = ...
SD.itemCategories={
    {key="bandage",label="Bandages",short="Bnd"},
    {key="heal",label="Healing Items",short="Heal"},
    {key="resource",label="Mana / resource Items",short="Mana"},
    {key="food",label="Food / buff food",short="Food"},
    {key="drink",label="Drink",short="Drink"},
    {key="weapon",label="Weapon Enhancements",short="Wpn"},
    {key="alternate",label="Potions / Flasks / Elixirs / Scrolls",short="Buff"},
}
local function safe(value) return not issecretvalue or not issecretvalue(value) end
local function plain(value) return type(value)=="string" and safe(value) and value:lower():gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","") or "" end
local function number(value) return tonumber(((value or ""):gsub("[, ]",""))) or 0 end
local function amount(text,word,maximum)
    local best = 0
    text = text:gsub("–", "-"):gsub("—", "-"):gsub(" to ", "-")
    text = text:gsub("%% of your maximum ", "%% "):gsub("%% of your ", "%% ")
    for low, high, percent in text:gmatch("([%d,.]+)%s*%-%s*([%d,.]+)(%%?)%s+"..word.."%f[%A]") do
        local value = (number(low) + number(high)) / 2
        if percent == "%" then value = value * (maximum or 0) / 100 end
        best = math.max(best, value)
    end
    text = text:gsub("([%d,.]+)%s*%-%s*([%d,.]+)(%%?)%s+"..word.."%f[%A]", "")
    for raw, percent in text:gmatch("([%d,.]+)(%%?)%s+"..word.."%f[%A]") do
        local value = number(raw)
        if percent == "%" then value = value * (maximum or 0) / 100 end
        best = math.max(best, value)
    end
    return best
end

-- Original First Aid ranks provide a fallback when tooltip text is unavailable.
local bandageHealing = {
    [1251]=66,[2581]=114,[3530]=161,[3531]=301,[6450]=400,[6451]=640,
    [8544]=800,[8545]=1104,[14529]=1360,[14530]=2000,
}

-- Classic ranks and improved-talent variants, independent of tooltip locale.
local healthstones = {
    [5512]=true,[19004]=true,[19005]=true,[5511]=true,[19006]=true,[19007]=true,
    [5509]=true,[19008]=true,[19009]=true,[5510]=true,[19010]=true,[19011]=true,
    [9421]=true,[19012]=true,[19013]=true,
}
local manaGems = {[5514]=true,[5513]=true,[8007]=true,[8008]=true}

local function recoveryFamily(id,name)
    if healthstones[id] or name:find("healthstone",1,true) then return "heal" end
    if manaGems[id] then return "resource" end
end

local function numeric(value)
    if safe(value) and type(value) == "number" then return value end
end

local function recoveryScore(value, fallback)
    return value > 0 and 1000000 + value or fallback
end
local function has(text,words)
    for _,word in ipairs(words) do if text:find(word,1,true) then return true end end
    return false
end
local recoveryWords={"restore","recover","replenish","regain","heals","healing you for","generates"}
local statWords={"strength","agility","intellect","stamina","spirit","armor","haste","critical strike","crit rating","versatility","mastery","attack power","spell power","spell damage","defense","resistance","primary stat","highest stat"}
local utilityWords={"invisibility","invisible","movement speed","swim speed","water breathing","water walking","slow fall","free action","removes all","bloodlust","heroism","sharpen","weightstone","weapon oil","apply to a weapon"}
local function isWeaponStone(name)
    local text=plain(name)
    return not text:find(":",1,true)
        and (text:match("weight%s*stone$") or text:match("sharpening%s+stone$") or text:match("whet%s*stone$")) ~= nil
end
local function isWeaponConsumable(item)
    return isWeaponStone(item.name)
        or has(plain(item.name),{"wizard oil","mana oil","weapon oil","instant poison","deadly poison","crippling poison","mind-numbing poison","wound poison","anesthetic poison"})
        or has(plain(item.description),{"apply to a weapon","applied to a weapon","coats a weapon"})
end
local function weaponEnchant(slot)
    if GetWeaponEnchantInfo then
        local main,_,_,_,off = GetWeaponEnchantInfo()
        if slot==16 then return main end
        return off
    end
    local slots=Enum and Enum.WeaponSlot
    local weaponSlot=slots and (slot==16 and slots.MainHand or slot==17 and slots.OffHand)
    if weaponSlot and C_Item and C_Item.GetWeaponEnchantInfo then
        for _,enchant in pairs(C_Item.GetWeaponEnchantInfo(weaponSlot) or {}) do
            if enchant.hasEnchant then return true end
        end
        return false
    end
end

local function updateWeaponStone(button, mouseButton)
    if mouseButton~="LeftButton" or not button.weaponStone or InCombatLockdown() then return end
    local getInfo=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    local target
    if getInfo and GetInventoryItemID then
        for slot=16,17 do
            local id=GetInventoryItemID("player",slot)
            local _,_,_,_,_,classID
            if id then _,_,_,_,_,classID=getInfo(id) end
            if classID==2 and weaponEnchant(slot)==false then
                target=slot
                break
            end
        end
    end
    button:SetAttribute("macrotext1",target and ("/use [nocombat] item:"..button.weaponStone.."\n/use [nocombat] "..target) or nil)
end

function SD:BindUtilityItem(button,item)
    button.weaponStone=item and not item.toy and not item.slot and isWeaponConsumable(item) and item.id or nil
    if button.weaponStone and not button.weaponStoneClickInstalled then
        button:HookScript("PreClick",updateWeaponStone)
        button.weaponStoneClickInstalled=true
    end
    button:SetAttribute("type1",button.weaponStone and "macro" or item and item.toy and "toy" or "item")
    button:SetAttribute("macrotext1",nil)
    button:SetAttribute("item1",item and (item.slot and tostring(item.slot) or "item:"..item.id) or nil)
end

local roleWeights = {
    TANK = {stamina=2.3, armor=0.2, defense=2, resistance=0.5, versatility=1.25},
    HEALER = {intellect=2, spirit=1.5, ["spell power"]=1.2, haste=1.15, ["attack power"]=0.05},
    DAMAGER = {stamina=0.2, armor=0.025, spirit=0.2, defense=0.1},
}

local ratingGlobals = {
    ["critical strike"]="CR_CRIT_MELEE", ["crit rating"]="CR_CRIT_MELEE",
    haste="CR_HASTE_MELEE", mastery="CR_MASTERY", versatility="CR_VERSATILITY_DAMAGE_DONE",
    defense="CR_DEFENSE_SKILL",
}

local function effectiveRatingGain(word, gain, context)
    local current = context.ratings and context.ratings[word]
    if not current or not GetCombatRatingBonusForCombatRatingValue then return gain end
    local convert = GetCombatRatingBonusForCombatRatingValue
    local rating, value = current[1], current[2]
    local base = numeric(convert(rating, 0))
    local first = numeric(convert(rating, 1))
    local before = numeric(convert(rating, value))
    local after = numeric(convert(rating, value + gain))
    if base and first and first > base and before and after then
        return math.max(0, (after-before)/(first-base))
    end
    return gain
end

local function statScore(text, word, stat, context)
    local gain = number(text:match(word.." rating by ([%d,.]+)") or text:match(word.." by ([%d,.]+)") or text:match("([%d,.]+) "..word))
    if gain == 0 then return 0 end
    local weights = roleWeights[context.role] or roleWeights.DAMAGER
    local weight = weights[word] or (word == stat and 1.8 or 1)
    -- Use a smaller marginal weight for piling more onto a large existing
    -- defensive stat. This is a ranking heuristic, not a rating conversion.
    local current = context.stats and context.stats[word]
    if current and current > 0 then
        local baseline = word == "armor" and 1000 or 100
        weight = weight * baseline / (baseline + current)
    end
    if text:find(word .. " rating", 1, true) or word == "crit rating" then
        gain = effectiveRatingGain(word, gain, context)
    end
    return gain * weight
end

function SD:GetConsumableSpec()
    local class
    if UnitClass then local _; _,class=UnitClass("player") end
    local classPrimary = {
        WARRIOR="strength", DEATHKNIGHT="strength", PALADIN="strength",
        HUNTER="agility", ROGUE="agility", DEMONHUNTER="agility",
        MAGE="intellect", PRIEST="intellect", WARLOCK="intellect", EVOKER="intellect",
    }
    local fallback=classPrimary[class] or "primary stat"
    local api=C_SpecializationInfo
    local index=api and api.GetSpecialization and api.GetSpecialization() or (GetSpecialization and GetSpecialization())
    local fn=api and api.GetSpecializationInfo or GetSpecializationInfo
    if index and fn then
        local id,name,_,_,role,stat=fn(index)
        local primary=class=="WARRIOR" and "strength" or ({[1]="strength",[2]="agility",[4]="intellect"})[stat]
        return tostring(id or 0),primary or fallback,name or "Current spec",role
    end
    return "0",fallback,"Current spec"
end
-- Classification reads item tooltips only outside combat. The score is an
-- inventory recommendation, never a decision based on combat health or auras.
function SD:ClassifyConsumable(item,stat,resource,context)
    context = context or {}
    local t=plain(item.description)
    local name=plain(item.name)
    local categories={}
    if isWeaponStone(item.name) then
        local damage = number(t:match("damage by ([%d,.]+)") or t:match("([%d,.]+) weapon damage"))
        categories.utility = recoveryScore(damage, (item.level or 0)*100+(item.quality or 0))
        categories.weapon=categories.utility
        return categories
    end
    resource=resource or "mana"
    local recovery=has(t,recoveryWords)
    local heal,mana=recovery and amount(t,"health",context.health) or 0,recovery and amount(t,"mana",context.mana) or 0
    local isFood=item.subclass==5
    local primary=t:find(stat,1,true) or t:find("primary stat",1,true) or t:find("highest stat",1,true)
    local otherPrimary=t:find("strength",1,true) or t:find("agility",1,true) or t:find("intellect",1,true)
    local base=(item.level or 0)*100+(item.quality or 0)
    local family=recoveryFamily(item.id,name)
    if family then
        if family=="heal" then categories.heal=recoveryScore(heal,base)
        elseif resource=="mana" then categories.resource=recoveryScore(mana,base) end
        return categories
    end
    if item.subclass==7 or name:find("bandage",1,true) then
        if heal==0 then
            heal=number(t:match("heals? .-for ([%d,.]+)") or t:match("([%d,.]+) damage over"))
        end
        if heal==0 then heal=bandageHealing[item.id] or 0 end
        categories.bandage=recoveryScore(heal,base)
    end
    local statBuff=has(t,statWords) or has(name,statWords)
    local eligible=not otherPrimary or primary
    local potion=item.subclass==1 or name:find("potion",1,true)
    local potency = 0
    for _,word in ipairs(statWords) do
        if word ~= "critical strike" or not t:find("crit rating",1,true) then
            potency = potency + statScore(t, word, stat, context)
        end
    end
    local buffScore = recoveryScore(potency, base)
    if potion or (item.hasUse and (item.subclass==0 or item.subclass==8)) then
        if heal>0 or name:find("healing potion",1,true) then categories.heal=recoveryScore(heal,base) end
        local restored=resource=="mana" and mana or 0
        if resource~="mana" and recovery then restored=amount(t,resource,context.power) end
        if restored>0 or name:find(resource.." potion",1,true) then categories.resource=recoveryScore(restored,base) end
        if potion and not categories.heal and not categories.resource and eligible and statBuff then
            categories.buffpotion=buffScore
        end
    end
    if isFood then
        local buff=has(t,{"well fed","well-fed","well nourished","eating for","spend at least"})
            or (statBuff and has(t,{"increas","grant","gain"}))
        if buff then
            -- Keep off-spec food browsable without recommending it.
            categories.bufffood=buffScore-(eligible and 0 or 20000000)
        else
            if heal>0 then categories.food=recoveryScore(heal,base) end
            if mana>0 then categories.drink=recoveryScore(mana,base) end
        end
    end
    if item.subclass==2 or item.subclass==3 or name:find("augment rune",1,true)
        or ((item.subclass==4 or name:find("scroll of ",1,true)) and statBuff) then
        if eligible then categories.alternate=buffScore end
    end
    if not next(categories) and (has(t,utilityWords) or has(name,utilityWords)
        or name:find("drums of ",1,true)) then
        categories.utility=base
    end
    -- Unrecognized on-use consumables remain available in the utility flyout.
    if not next(categories) and item.hasUse and (eligible or not statBuff) then
        categories.utility=base-1000000
    end
    if isWeaponConsumable(item) then categories.weapon=base end
    return categories,not not (categories.bufffood and not eligible)
end

function SD:ScanConsumables()
    if InCombatLockdown() then self.itemsDirty=true return false end
    if not C_Item or not C_Item.GetItemInfo or not C_Container or not C_Container.GetContainerItemInfo then return false end
    local spec,stat,specName,role=self:GetConsumableSpec()
    self.itemSpecName=specName
    local resourceToken
    if UnitPowerType then local _; _,resourceToken=UnitPowerType("player") end
    local resource=({MANA="mana",RAGE="rage",ENERGY="energy",FOCUS="focus",RUNIC_POWER="runic power"})[resourceToken] or "mana"
    local context = {
        role = role or (UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")),
        health = UnitHealthMax and numeric(UnitHealthMax("player")),
        power = UnitPowerMax and numeric(UnitPowerMax("player")),
        mana = UnitPowerMax and numeric(UnitPowerMax("player",0)),
        stats = {},
    }
    if UnitArmor then
        local _, armor = UnitArmor("player")
        context.stats.armor = numeric(armor)
    end
    if UnitStat then
        local _, stamina = UnitStat("player",3)
        context.stats.stamina = numeric(stamina)
        local _, spirit = UnitStat("player",5)
        context.stats.spirit = numeric(spirit)
    end
    if GetCombatRating then
        context.ratings = {}
        for word, global in pairs(ratingGlobals) do
            local rating = _G[global]
            local value = rating and numeric(GetCombatRating(rating))
            if value then context.ratings[word] = {rating, value} end
        end
    end
    local instanceType
    if IsInInstance then local _; _,instanceType=IsInInstance() end
    local inPvp=instanceType=="pvp" or instanceType=="arena"
    self.itemSpec=spec
    local all,seen={},{}
    local lists={}
    for _,category in ipairs(self.itemCategories) do lists[category.key]={} end
    -- Keep legacy pools and saved rules available; the bar groups them into ten slots.
    for _,key in ipairs({"bufffood","buffpotion","utility"}) do lists[key]={} end
    local playerLevel=UnitLevel and UnitLevel("player") or 999
    local maxBag=NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5
    for bag=0,maxBag do
        for slot=1,C_Container.GetContainerNumSlots(bag) do
            local bagInfo=C_Container.GetContainerItemInfo(bag,slot)
            local id=bagInfo and bagInfo.itemID
            if id and safe(id) and not seen[id] then
                seen[id]=true
                local name,link,quality,level,minLevel,_,_,_,_,icon,_,class,subclass=C_Item.GetItemInfo(id)
                local weaponStone=name and class~=9 and isWeaponStone(name)
                local family=name and recoveryFamily(id,plain(name))
                if name and (class==0 or weaponStone or family) and (minLevel or 0)<=playerLevel then
                    local description={}
                    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
                        local tip=C_TooltipInfo.GetBagItem(bag,slot)
                        for _,line in ipairs(tip and tip.lines or {}) do
                            if safe(line.leftText) then description[#description+1]=line.leftText or "" end
                        end
                    end
                    local item={id=id,name=name,link=link,icon=icon,quality=quality,level=level,subclass=subclass,description=table.concat(description," ")}
                    local usable=true
                    -- A stone needs a weapon target. A negative standalone
                    -- usability result must not remove the targeting button.
                    if C_Item.IsUsableItem and not isWeaponConsumable(item) and subclass~=5 then usable=C_Item.IsUsableItem(id) end
                    local desc=plain(item.description)
                    if not inPvp and (desc:find("only usable in battlegrounds",1,true) or desc:find("only be used in battlegrounds",1,true)
                        or desc:find("only usable in rated",1,true)) then usable=false end
                    if usable then
                        local useSpell=class==0 and C_Item.GetItemSpell and C_Item.GetItemSpell(id)
                        item.hasUse=class==0 and ((safe(useSpell) and not not useSpell) or desc:find("use:",1,true)~=nil)
                        item.categories,item.offSpecFood=self:ClassifyConsumable(item,stat,resource,context)
                        all[#all+1]=item
                        for key,score in pairs(item.categories) do
                            lists[key][#lists[key]+1]={item=item,score=score}
                        end
                    end
                elseif not name and C_Item.RequestLoadItemDataByID then self:RequestItemData(id) end
            end
        end
    end
    for _,list in pairs(lists) do table.sort(list,function(a,b) if a.score==b.score then return a.item.id<b.item.id end return a.score>b.score end) end
    table.sort(all,function(a,b)return a.name<b.name end)
    self.consumableLists,self.allConsumables=lists,all
    self.itemsDirty=nil
    return true
end

function SD:GetChosenItem(key)
    local overrides=self.db.itemOverrides[self.itemSpec or "0"] or {}
    local wanted=overrides[key]
    if not wanted and key=="food" then wanted=overrides.bufffood end
    if not wanted and key=="alternate" then wanted=overrides.buffpotion end
    if not wanted and key=="weapon" and overrides.utility then
        for _,item in ipairs(self.allConsumables or {}) do
            if item.id==overrides.utility and isWeaponConsumable(item) then wanted=item.id break end
        end
    end
    if wanted then
        for _,item in ipairs(self.allConsumables or {}) do if item.id==wanted and self:GetItemRule(key,item.id)~=false then return item,true end end
        return nil,true -- A pinned item never silently becomes another item.
    end
    local list=self:GetUtilityChoices(key)
    for _,item in ipairs(list) do
        if (key~="bufffood" and key~="food") or not item.offSpecFood then return item,false end
    end
    return nil,false
end

local function font(parent,size)
    local f=parent:CreateFontString(nil,"OVERLAY") f:SetFont("Fonts\\FRIZQT__.TTF",size,"OUTLINE") return f
end
function SD:CreateUtilityButtons()
    if self.utilityButtons or InCombatLockdown() then return end
    -- Independent of the decorative canvas: protected buttons are not hidden
    -- by an unprotected artwork parent during combat or Edit Mode.
    self.utilityRoot=CreateFrame("Frame","StoneDockUtilityRoot",UIParent)
    self.utilityRoot:SetFrameStrata("MEDIUM")
    self.utilityRoot.backdrop=self.utilityRoot:CreateTexture(nil,"BACKGROUND")
    self.utilityRoot.backdrop:SetPoint("TOPLEFT",self.utilityRoot,"TOPLEFT",-3,3)
    self.utilityRoot.backdrop:SetPoint("BOTTOMRIGHT",self.utilityRoot,"BOTTOMRIGHT",3,-3)
    self.utilityRoot.backdrop:SetColorTexture(0,0,0,0)
    self.utilityButtons={}
    for i=1,2+#self.itemCategories do
        local b=CreateFrame("Button","StoneDockUtility"..i,self.utilityRoot,"SecureActionButtonTemplate")
        b:SetSize(24,24) b:RegisterForClicks("AnyUp","AnyDown")
        b:SetAttribute("type1","item")
        b.icon=b:CreateTexture(nil,"ARTWORK") b.icon:SetAllPoints()
        b.icon:SetTexCoord(.06,.94,.06,.94)
        b.border=b:CreateTexture(nil,"BACKGROUND") b.border:SetPoint("TOPLEFT",-1,1) b.border:SetPoint("BOTTOMRIGHT",1,-1) b.border:SetColorTexture(0,0,0,0)
        b.count=font(b,9) b.count:SetPoint("BOTTOMRIGHT",1,-1)
        b.empty=font(b,7) b.empty:SetPoint("CENTER")
        b.cooldown=CreateFrame("Cooldown",nil,b,"CooldownFrameTemplate") b.cooldown:SetAllPoints()
        if i<=2 then b.inventorySlot=12+i b.label=i==1 and "Upper equipped trinket" or "Lower equipped trinket"
        else b.category=self.itemCategories[i-2] b.label=b.category.label end
        b:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_TOP")
            if self.inventorySlot and GameTooltip.SetInventoryItem then GameTooltip:SetInventoryItem("player",self.inventorySlot)
            elseif self.itemID and GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.itemID)
            else GameTooltip:AddLine(self.label) end
            if self.weaponStone then
                GameTooltip:AddLine("Applies to the main hand first, then the off-hand. Skips weapons with a temporary enchant.",.65,.75,.85,true)
            end
            if self.category then
                GameTooltip:AddLine("Right-click: expand available items upward. Configure defaults in Item settings.",.65,.75,.85,true)
                GameTooltip:AddLine(self.pinned and "Pinned for this spec" or "Auto: strongest suitable item found in your bags",.65,.75,.85,true)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        b:HookScript("OnClick",function(self,button,down)
            if button=="RightButton" and not down then SD:Run("Choose consumable",function() SD:ShowUtilityFlyout(self,self.category and self.category.key or "trinkets") end) end
        end)
        self:RegisterUsageButton(b,b.inventorySlot and ("Trinket slot "..b.inventorySlot) or ("Item category: "..b.category.key))
        self.utilityButtons[i]=b
    end
    if self.CreateHearthButton then self:CreateHearthButton() end
end

function SD:UpdateUtilityCooldowns()
    if not self.utilityRoot or not self.utilityRoot:IsShown() or (self.utilityRoot.IsVisible and not self.utilityRoot:IsVisible()) then return end
    for _,b in ipairs(self.utilityButtons or {}) do
        if b:IsShown() and b.inventorySlot and GetInventoryItemCooldown then
            local start,duration=GetInventoryItemCooldown("player",b.inventorySlot)
            if safe(start) and safe(duration) and start and duration then b.cooldown:SetCooldown(start,duration) end
        elseif b:IsShown() and b.itemID and C_Item and C_Item.GetItemCooldown then
            local start,duration=C_Item.GetItemCooldown(b.itemID)
            if safe(start) and safe(duration) and start and duration then b.cooldown:SetCooldown(start,duration) end
        end
        if b:IsShown() and not b.hearth and not b.inventorySlot and b.itemID and C_Item and C_Item.GetItemCount then
            local count=C_Item.GetItemCount(b.itemID,false)
            b.count:SetText(safe(count) and count or "")
        end
    end
end
function SD:RefreshUtilityButtons(scan)
    if not self.db then return end
    if InCombatLockdown() then self.itemsDirty=true return end
    self:CreateUtilityButtons()
    if not self.utilityButtons then return end
    if scan then self:ScanConsumables() end
    local g=self:GetGeometry()
    self.utilityRoot:SetScale(g.scale)
    self.utilityRoot:SetShown(self.db.enabled and self.db.showUtility and self:IsOurLayoutActive() and not self.editing)
    for i,b in ipairs(self.utilityButtons) do
        local previousItemID=b.itemID
        if b.hearth then self:RefreshHearthButton(scan)
        elseif b.inventorySlot then
            b.itemID=GetInventoryItemID and GetInventoryItemID("player",b.inventorySlot)
            if b.itemID and self:GetItemRule("trinkets",b.itemID)==false then b.itemID=nil end
            b:SetAttribute("type1",b.itemID and "item" or nil)
            b:SetAttribute("item1",b.itemID and tostring(b.inventorySlot) or nil)
            b.icon:SetTexture(GetInventoryItemTexture and GetInventoryItemTexture("player",b.inventorySlot) or 134400)
            b.empty:SetText(b.itemID and "" or (i==1 and "T1" or "T2"))
        else
            local item,pinned=self:GetChosenItem(b.category.key)
            b.itemID,b.pinned=item and item.id,pinned
            self:BindUtilityItem(b,item)
            b.icon:SetTexture(item and item.icon or 134400)
            b.empty:SetText(item and "" or b.category.short)
            b.icon:SetDesaturated(not item)
            if not item then b.count:SetText("") end
        end
        if b.itemID~=previousItemID then b.cooldown:SetCooldown(0,0) end
    end
    -- Secure controls only change visibility and position outside combat.
    -- Only the two trinket seats persist; available categories pack in order.
    self.utilityRoot:SetScale(g.scale)
    local size,spacing=g.utilityIconSize or 24*.85,g.utilityIconSize and 2 or 4
    local width=g.itemWell and g.itemWell.w or g.bagDrawer.w-12
    size=math.min(size,math.max(1,(width-9*spacing)/10))
    local visible,availableCount=0,0
    for _,b in ipairs(self.utilityButtons) do
        local available=b.itemID~=nil
        local show=b.inventorySlot~=nil or available
        b:SetShown(show)
        b:SetSize(size,size) b:ClearAllPoints()
        if show then b:SetPoint("BOTTOMLEFT",self.utilityRoot,"BOTTOMLEFT",visible*(size+spacing),0) visible=visible+1 end
        if available then availableCount=availableCount+1 end
        b.icon:SetAlpha(available and 1 or 0)
        if b.empty then b.empty:SetText("") end
        if not available then b.count:SetText("") end
        b.stoneDockUtilityBorder=true
        self:SetSoftBarBorder(b,g.variant=="adept")
    end
    width=math.max(size,visible*(size+spacing)-spacing)
    self.utilityRoot:ClearAllPoints()
    if g.itemWell then
        self.utilityRoot:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",g.itemWell.x,g.itemWell.y)
    elseif g.variant=="gulveig" and ChatFrame1 then
        -- A live native anchor preserves clearance as chat moves or grows.
        -- This secure root is positioned only in this out-of-combat refresh.
        self.utilityRoot:SetPoint("BOTTOMRIGHT",ChatFrame1,"TOPRIGHT",22,44)
    else
        self.utilityRoot:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",g.bagDrawer.x+6,g.utilityY)
    end
    local saved=self.db.utilityPositions and self.db.utilityPositions[g.variant or "stone"]
    if saved then
        self.utilityRoot:ClearAllPoints()
        self.utilityRoot:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",saved.x,saved.y)
    end
    self.utilityRoot:SetSize(width,size)
    self:RefreshUtilityMover()
    local shown=self.utilityRoot:IsShown() and availableCount>0
    if not shown and self.utilityTicker then self.utilityTicker:Cancel()self.utilityTicker=nil end
    if shown and not self.utilityTicker then self.utilityTicker=C_Timer.NewTicker(.5,function()SD:UpdateUtilityCooldowns()end)end
    self:UpdateUtilityCooldowns()
end

function SD:RefreshUtilityMover()
    local mover=self.utilityMover
    if not mover then return end
    if not self.utilityMoveMode or InCombatLockdown() or not self.utilityRoot:IsShown() then mover:Hide() return end
    if mover.dragging then return end
    local root=self.utilityRoot
    local x,y=root:GetLeft(),root:GetBottom()
    if not x or not y then return end
    mover:SetScale(root:GetScale()) mover:ClearAllPoints()
    mover:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",x,y)
    mover:SetSize(math.max(100,root:GetWidth()),root:GetHeight()+14)
    mover:Show()
end
function SD:FinishUtilityDrag()
    local mover=self.utilityMover
    if not mover or not mover.dragging then return end
    mover.dragging=nil mover:StopMovingOrSizing()
    local g=self:GetGeometry()
    local x,y=mover:GetLeft(),mover:GetBottom()
    if not x or not y then return end
    self.db.utilityPositions=self.db.utilityPositions or {}
    self.db.utilityPositions[mover.variant or g.variant or "stone"]={x=x,y=y}
    mover.variant=nil
    self.utilityMoveMode=false
    if InCombatLockdown() then self.itemsDirty=true return end
    self:RefreshUtilityButtons(false)
end
function SD:ToggleUtilityMover(reset)
    if self:IsBusy() then SD.Print("Move the item bar outside combat and Edit Mode.") return end
    self:CreateUtilityButtons()
    if reset then
        if self.db.utilityPositions then self.db.utilityPositions[self:GetGeometry().variant or "stone"]=nil end
        self.utilityMoveMode=false self:RefreshUtilityButtons(false) return
    end
    if not self.utilityMover then
        -- A separate drag ghost never moves secure item buttons during combat.
        local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate") self.utilityMover=f
        f:SetFrameStrata("DIALOG") f:SetMovable(true) f:EnableMouse(true) f:RegisterForDrag("LeftButton") f:SetClampedToScreen(true)
        f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        f:SetBackdropColor(0,0,0,.6) f:SetBackdropBorderColor(.8,.7,.4,1)
        local t=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall") t:SetPoint("TOPLEFT",3,-1) t:SetText("ITEM BAR - DRAG")
        f:SetScript("OnDragStart",function()if not InCombatLockdown() then f.variant=SD:GetGeometry().variant or "stone" f.dragging=true f:StartMoving() end end)
        f:SetScript("OnDragStop",function()SD:FinishUtilityDrag()end)
        f:Hide()
    end
    self.utilityMoveMode=not self.utilityMoveMode
    self:RefreshUtilityMover()
    SD.Print(self.utilityMoveMode and "Drag the item-bar outline; release to save and lock." or "Item-bar position saved.")
end
SD:On("PLAYER_REGEN_DISABLED",function()
    if SD.utilityMover then SD:FinishUtilityDrag() SD.utilityMoveMode=false SD.utilityMover:Hide() end
end)
function SD:QueueConsumables()
    self.itemsDirty=true
    if self.itemsPending then return end
    self.itemsPending=true
    C_Timer.After(.4,function()
        if SD.db and SD.itemsDirty then SD:Run("Refresh consumables",function() SD:RefreshUtilityButtons(true) end) end
        SD.itemsPending=nil
    end)
end
SD:On("PLAYER_LOGIN",function() SD:RefreshUtilityButtons(true) end)
SD:On("BAG_UPDATE_DELAYED",function() SD:QueueConsumables() end)
SD:On("PLAYER_EQUIPMENT_CHANGED",function() SD:QueueConsumables() end)
SD:On("PLAYER_LEVEL_UP",function() SD:QueueConsumables() end)
SD:On("PLAYER_SPECIALIZATION_CHANGED",function() SD:QueueConsumables() end)
SD:On("PLAYER_ENTERING_WORLD",function() SD:QueueConsumables() end)
SD:On("PLAYER_REGEN_ENABLED",function() if SD.itemsDirty then SD:RefreshUtilityButtons(true) end end)

