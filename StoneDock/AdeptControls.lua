local _, SD = ...
local skins, hidden, surrounds = {}, {}, {}
local owned = setmetatable({}, {__mode="k"})
local alphaHooks=setmetatable({}, {__mode="k"})
local enabled, queued
local media="Interface\\AddOns\\StoneDock\\Media\\AdeptSurface"

local function queue()
    if queued then return end
    queued=true
    C_Timer.After(0,function()
        queued=nil
        if SD.db then SD:RefreshAdeptControlArt() end
    end)
end

local function hideTexture(texture)
    if not texture or owned[texture] or not texture.SetAlpha then return end
    if hidden[texture]==nil then hidden[texture]=texture:GetAlpha() end
    if hooksecurefunc and not alphaHooks[texture] then
        alphaHooks[texture]=true
        hooksecurefunc(texture,"SetAlpha",function(region,alpha)
            if enabled and hidden[region]~=nil and alpha~=0 then region:SetAlpha(0) end
        end)
    end
    texture:SetAlpha(0)
end

local function suppress(frame,depth)
    if not frame or depth>2 then return end
    for _,getter in ipairs({"GetNormalTexture","GetPushedTexture","GetHighlightTexture","GetDisabledTexture","GetCheckedTexture","GetDisabledCheckedTexture"}) do
        if frame[getter] then hideTexture(frame[getter](frame)) end
    end
    if frame.GetRegions then
        for _,region in ipairs({frame:GetRegions()}) do
            if region.IsObjectType and region:IsObjectType("Texture") then hideTexture(region) end
        end
    end
    if frame.GetChildren then
        for _,child in ipairs({frame:GetChildren()}) do
            local name=(child.GetName and child:GetName() or ""):lower()
            -- Preserve notification bubbles, tutorial pulses, counters and secure child buttons.
            if not child.stoneDockAdeptControl and not name:find("alert",1,true)
                and not name:find("pulse",1,true) and not name:find("flash",1,true)
                and not name:find("notification",1,true) and not name:find("tutorial",1,true) and not name:find("indicator",1,true)
                and not (child.IsObjectType and child:IsObjectType("Button")) then suppress(child,depth+1) end
        end
    end
end

function SD:GetAdeptBagGlyph(button)
    local name=(button.GetName and button:GetName() or ""):lower()
    if name:find("quiver",1,true) or name:find("ammo",1,true) then return "quiver" end
    if name:find("key",1,true) or button.isKeyRing then return "keyring" end
    if name:find("reagent",1,true) or button.isReagentBag then return "reagent" end
    local id=button.GetID and button:GetID()
    if type(id)=="number" and (not issecretvalue or not issecretvalue(id)) then
        if id==-2 then return "keyring" end
        if id==5 then return "reagent" end
    end
    local slot=button.GetInventorySlot and button:GetInventorySlot()
    local index=name:match("characterbag(%d+)slot")
    if not slot and index then slot=20+tonumber(index) end
    local info=(C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if slot and GetInventoryItemID and info then
        local item=GetInventoryItemID("player",slot)
        if item then
            local _,_,_,_,_,class=info(item)
            if type(class)=="number" and (not issecretvalue or not issecretvalue(class)) and class==11 then return "quiver" end
        end
    end
    return name:find("backpack",1,true) and "backpack" or "bag"
end

local function glyphKind(button,bag)
    if bag then return SD:GetAdeptBagGlyph(button) end
    local name=(button.GetName and button:GetName() or ""):lower()
    if name:find("expand",1,true) then return "toggle" end
    for _,spec in ipairs({{"character","person"},{"spell","book"},{"skill","tools"},{"talent","tree"},
        {"achievement","medal"},{"quest","quest"},{"social","people"},{"guild","shield"},
        {"lfd","search"},{"lfg","search"},{"group","search"},{"pvp","tools"},
        {"collection","bag"},{"journal","book"},{"encounter","book"},{"store","gem"},
        {"help","help"},{"mainmenu","menu"},{"worldmap","map"}}) do
        if name:find(spec[1],1,true) then return spec[2] end
    end
    return "menu"
end

local function createSkin(button,kind)
    local art={textures={},glyphs={}}
    local function texture(layer)
        local t=button:CreateTexture(nil,layer or "OVERLAY",nil,1)
        owned[t]=true art.textures[#art.textures+1]=t
        return t
    end
    art.fill=texture("BACKGROUND")
    art.fill:SetTexture(media,"REPEAT","REPEAT") art.fill:SetAllPoints()
    art.fill:SetVertexColor(.48,.49,.5,1)
    art.hover=texture("ARTWORK") art.hover:SetAllPoints()
    art.hover:SetColorTexture(.82,.71,.46,.12) art.hover:Hide()
    for _,edge in ipairs({{"TOPLEFT","TOPRIGHT",true},{"BOTTOMLEFT","BOTTOMRIGHT",true},
        {"TOPLEFT","BOTTOMLEFT",false},{"TOPRIGHT","BOTTOMRIGHT",false}}) do
        local t=texture("BORDER") t:SetColorTexture(.52,.47,.35,.8)
        t:SetPoint(edge[1],button,edge[1],0,0) t:SetPoint(edge[2],button,edge[2],0,0)
        if edge[3] then t:SetHeight(1) else t:SetWidth(1) end
    end
    local icon=texture()
    icon:SetTexture("Interface\\AddOns\\StoneDock\\Media\\AdeptControlGlyphs")
    icon:SetSize(24,24)
    icon:SetPoint("CENTER",button,"CENTER",0,0)
    icon:SetVertexColor(.84,.76,.57,1)
    art.glyphs[1]=icon
    art.setKind=function(value)
        local index=1
        for i,name in ipairs({"person", "book", "tools", "tree", "medal", "quest", "shield", "people", "search", "bag", "gem", "help", "menu", "map", "toggle", "backpack", "quiver", "keyring", "reagent"}) do if name==value then index=i break end end
        local col,row=(index-1)%8,math.floor((index-1)/8)
        icon:SetTexCoord(col/8,(col+1)/8,row/4,(row+1)/4)
        art.kind=value
    end
    art.setKind(kind)
    art.update=function()
        local on=enabled and art.active
        local usable=not button.IsEnabled or button:IsEnabled()
        if on then suppress(button,0) end
        for _,t in ipairs(art.textures) do t:SetShown(not not on) end
        art.hover:SetShown(on and art.over and usable)
        for _,t in ipairs(art.glyphs) do t:SetAlpha(usable and (art.down and .55 or 1) or .35) end
    end
    button:HookScript("OnEnter",function() art.over=true art.update() end)
    button:HookScript("OnLeave",function() art.over=false art.update() end)
    button:HookScript("OnMouseDown",function() art.down=true art.update() end)
    button:HookScript("OnMouseUp",function() art.down=false art.update() end)
    button:HookScript("OnShow",queue)
    return art
end

function SD:RefreshAdeptControlArt()
    if InCombatLockdown() then self.adeptControlArtAfterCombat=true return end
    enabled=self.db and self.db.enabled and self.layoutName=="Adept" and not self.editing and self:IsOurLayoutActive()
    if not self.adeptMicroUpdateHooked and hooksecurefunc and type(UpdateMicroButtons)=="function" then
        self.adeptMicroUpdateHooked=true
        hooksecurefunc("UpdateMicroButtons",queue)
    end
    self.adeptControlBarHooks=self.adeptControlBarHooks or {}
    for _,parent in pairs({MicroMenu,BagsBar}) do
        if not self.adeptControlBarHooks[parent] then
            parent:HookScript("OnShow",queue)
            self.adeptControlBarHooks[parent]=true
        end
        local surround=surrounds[parent]
        if enabled and not surround then
            surround=CreateFrame("Frame",nil,parent,"BackdropTemplate")
            surround.stoneDockAdeptControl=true
            surround:EnableMouse(false)
            surround:SetFrameLevel(math.max(0,parent:GetFrameLevel()-1))
            surround:SetPoint("TOPLEFT",parent,"TOPLEFT",-3,3)
            surround:SetPoint("BOTTOMRIGHT",parent,"BOTTOMRIGHT",3,-3)
            surround:SetBackdrop({bgFile=media,edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1,tile=true,tileSize=64})
            surround:SetBackdropColor(.4,.41,.42,1)
            surround:SetBackdropBorderColor(.55,.49,.35,.8)
            surrounds[parent]=surround
        end
        if surround then surround:SetShown(not not enabled) end
    end
    local wanted={}
    local function add(button,bag)
        if not button or wanted[button] or not button.CreateTexture or not button.HookScript then return end
        wanted[button]=true
        local art=skins[button]
        local kind=glyphKind(button,bag)
        if not art then art=createSkin(button,kind) skins[button]=art
        elseif art.kind~=kind then art.setKind(kind) end
        art.active=true
        suppress(button,0)
        art.update()
    end
    if enabled then
        for _,name in ipairs({"CharacterMicroButton","SpellbookMicroButton","SkillsMicroButton","TalentMicroButton",
            "AchievementMicroButton","QuestLogMicroButton","SocialsMicroButton","GuildMicroButton","LFDMicroButton",
            "LFGMicroButton","PVPMicroButton","CollectionsMicroButton","EJMicroButton","StoreMicroButton",
            "MainMenuMicroButton","HelpMicroButton","WorldMapMicroButton"}) do add(_G[name]) end
        if MicroMenu and MicroMenu.GetChildren then
            for _,button in ipairs({MicroMenu:GetChildren()}) do
                if button.layoutIndex and button.IsObjectType and button:IsObjectType("Button") then add(button) end
            end
        end
        if MainMenuBarBagManager and MainMenuBarBagManager.EnumerateBagButtons then
            for _,button in MainMenuBarBagManager:EnumerateBagButtons() do add(button,true) end
        else
            add(MainMenuBarBackpackButton,true)
            for i=0,3 do add(_G["CharacterBag"..i.."Slot"],true) end
        end
        add(BagBarExpandToggle)
        -- Remove only the old shared artwork; never change native button layout.
        for _,frame in pairs({MicroMenu,MicroMenuContainer,BagsBar,MicroButtonAndBagsBar}) do
            if frame and frame.GetRegions then
                for _,region in ipairs({frame:GetRegions()}) do
                    if region.IsObjectType and region:IsObjectType("Texture") then hideTexture(region) end
                end
            end
        end
    end
    for button,art in pairs(skins) do
        if not wanted[button] then art.active=false art.update() end
    end
    if not enabled then
        for texture,alpha in pairs(hidden) do texture:SetAlpha(alpha) end
        hidden={}
    end
    self.adeptControlArtAfterCombat=nil
end

SD:On("PLAYER_REGEN_ENABLED",function() if SD.adeptControlArtAfterCombat then SD:RefreshAdeptControlArt() end end)
SD:On("PLAYER_ENTERING_WORLD",queue)
SD:On("PLAYER_LEVEL_CHANGED",queue)
SD:On("PLAYER_EQUIPMENT_CHANGED",queue)

SD:On("BAG_UPDATE_DELAYED",queue)
SD:On("UNIT_PORTRAIT_UPDATE",function(unit) if unit=="player" then queue() end end)
