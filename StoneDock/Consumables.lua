local _, SD = ...
SD.itemCategories={
    {key="bandage",label="Bandage",short="Bnd"},{key="heal",label="Healing potion",short="Heal"},
    {key="resource",label="Resource potion",short="Res"},{key="bufffood",label="Buff food for current spec",short="Meal"},
    {key="buffpotion",label="Buff potion",short="Pot"},{key="alternate",label="Flask / elixir / scroll",short="Buff"},
    {key="food",label="Health food",short="Food"},{key="drink",label="Mana drink",short="Drink"},
    {key="utility",label="Utility consumable",short="Util"},
}
local function safe(value) return not issecretvalue or not issecretvalue(value) end
local function plain(value) return type(value)=="string" and safe(value) and value:lower():gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","") or "" end
local function number(value) return tonumber(((value or ""):gsub("[, ]",""))) or 0 end
local function amount(text,word,maximum)
    local best = 0
    text = text:gsub("–", "-"):gsub("—", "-"):gsub(" to ", "-")
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
local recoveryWords={"restore","recover","replenish","regain","heals","healing you for"}
local statWords={"strength","agility","intellect","stamina","spirit","armor","haste","critical strike","crit rating","versatility","mastery","attack power","spell power","spell damage","defense","resistance","primary stat","highest stat"}
local utilityWords={"invisibility","invisible","movement speed","swim speed","water breathing","water walking","slow fall","free action","removes all","bloodlust","heroism","sharpen","weightstone","weapon oil","apply to a weapon"}
local function isWeaponStone(name)
    local text=plain(name)
    return not text:find(":",1,true)
        and (text:match("weight%s*stone$") or text:match("sharpening%s+stone$")) ~= nil
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
        return categories
    end
    resource=resource or "mana"
    local recovery=has(t,recoveryWords)
    local heal,mana=recovery and amount(t,"health",context.health) or 0,recovery and amount(t,"mana",context.mana) or 0
    local isFood=item.subclass==5
    local primary=t:find(stat,1,true) or t:find("primary stat",1,true) or t:find("highest stat",1,true)
    local otherPrimary=t:find("strength",1,true) or t:find("agility",1,true) or t:find("intellect",1,true)
    local base=(item.level or 0)*100+(item.quality or 0)
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
    if potion then
        if heal>0 or name:find("healing potion",1,true) then categories.heal=recoveryScore(heal,base) end
        local restored=recovery and amount(t,resource,context.power) or 0
        if restored>0 or name:find(resource.." potion",1,true) then categories.resource=recoveryScore(restored,base) end
        if not categories.heal and not categories.resource and eligible and statBuff then
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
                if name and (class==0 or weaponStone) and (minLevel or 0)<=playerLevel then
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
                    if C_Item.IsUsableItem and not weaponStone and subclass~=5 then usable=C_Item.IsUsableItem(id) end
                    local desc=plain(item.description)
                    if not inPvp and (desc:find("only usable in battlegrounds",1,true) or desc:find("only be used in battlegrounds",1,true)
                        or desc:find("only usable in rated",1,true)) then usable=false end
                    if usable then
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
    if wanted then
        for _,item in ipairs(self.allConsumables or {}) do if item.id==wanted and self:GetItemRule(key,item.id)~=false then return item,true end end
        return nil,true -- A pinned item never silently becomes another item.
    end
    local list=self:GetUtilityChoices(key)
    for _,item in ipairs(list) do
        if key~="bufffood" or not item.offSpecFood then return item,false end
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
    self.utilityButtons={}
    for i=1,2+#self.itemCategories do
        local b=CreateFrame("Button","StoneDockUtility"..i,self.utilityRoot,"SecureActionButtonTemplate")
        b:SetSize(24,24) b:RegisterForClicks("AnyUp","AnyDown")
        b:SetAttribute("type1","item")
        b.icon=b:CreateTexture(nil,"ARTWORK") b.icon:SetAllPoints()
        b.icon:SetTexCoord(.06,.94,.06,.94)
        b.border=b:CreateTexture(nil,"BACKGROUND") b.border:SetPoint("TOPLEFT",-1,1) b.border:SetPoint("BOTTOMRIGHT",1,-1) b.border:SetColorTexture(.4,.45,.5,1)
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
            b:SetAttribute("item1",tostring(b.inventorySlot))
            b.icon:SetTexture(GetInventoryItemTexture and GetInventoryItemTexture("player",b.inventorySlot) or 134400)
            b.empty:SetText(b.itemID and "" or (i==1 and "T1" or "T2"))
        else
            local item,pinned=self:GetChosenItem(b.category.key)
            b.itemID,b.pinned=item and item.id,pinned
            b:SetAttribute("item1",item and ("item:"..item.id) or nil)
            b.icon:SetTexture(item and item.icon or 134400)
            b.empty:SetText(item and "" or b.category.short)
            b.icon:SetDesaturated(not item)
            if not item then b.count:SetText("") end
        end
        if b.itemID~=previousItemID then b.cooldown:SetCooldown(0,0) end
    end
    -- Secure controls only change visibility and position outside combat.
    -- Keep both ends fixed to the bag drawer regardless of available categories.
    local size,spacing=24*.85,4
    local width=g.bagDrawer.w-12
    local trinkets,items={},{}
    for _,b in ipairs(self.utilityButtons) do
        local available=b.hearth and b.hasAvailable or (not b.hearth and b.itemID~=nil)
        b:SetShown(not not available)
        b:SetSize(size,size)
        if available then
            local group=b.inventorySlot and trinkets or items
            group[#group+1]=b
        end
    end
    for i,b in ipairs(trinkets) do
        b:ClearAllPoints() b:SetPoint("BOTTOMLEFT",self.utilityRoot,"BOTTOMLEFT",(i-1)*(size+spacing),0)
    end
    -- Preserve category order; new available items extend the row toward the left.
    for i,b in ipairs(items) do
        b:ClearAllPoints() b:SetPoint("BOTTOMLEFT",self.utilityRoot,"BOTTOMLEFT",width-size-(#items-i)*(size+spacing),0)
    end
    self.utilityRoot:ClearAllPoints()
    self.utilityRoot:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",g.bagDrawer.x+6,g.utilityY)
    self.utilityRoot:SetSize(width,size)
    local shown=self.utilityRoot:IsShown() and (#trinkets+#items)>0
    if not shown and self.utilityTicker then self.utilityTicker:Cancel()self.utilityTicker=nil end
    if shown and not self.utilityTicker then self.utilityTicker=C_Timer.NewTicker(.5,function()SD:UpdateUtilityCooldowns()end)end
    self:UpdateUtilityCooldowns()
end

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

