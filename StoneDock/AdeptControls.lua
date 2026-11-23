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

local function glyphKind(name,bag)
    if bag then return "bag" end
    if name and name:lower():find("expand",1,true) then return "toggle" end
    name=(name or ""):lower()
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
    art.fill:SetVertexColor(.25,.26,.27,1)
    art.hover=texture("ARTWORK") art.hover:SetAllPoints()
    art.hover:SetColorTexture(.82,.71,.46,.12) art.hover:Hide()
    for _,edge in ipairs({{"TOPLEFT","TOPRIGHT",true},{"BOTTOMLEFT","BOTTOMRIGHT",true},
        {"TOPLEFT","BOTTOMLEFT",false},{"TOPRIGHT","BOTTOMRIGHT",false}}) do
        local t=texture("BORDER") t:SetColorTexture(.52,.47,.35,.8)
        t:SetPoint(edge[1],button,edge[1],0,0) t:SetPoint(edge[2],button,edge[2],0,0)
        if edge[3] then t:SetHeight(1) else t:SetWidth(1) end
    end
    local function path(points)
        for i=2,#points do
            local a,b=points[i-1],points[i]
            local dx,dy=b[1]-a[1],b[2]-a[2]
            local t=texture()
            t:SetColorTexture(.84,.76,.57,1)
            t:SetSize(math.sqrt(dx*dx+dy*dy),1.25)
            t:SetPoint("CENTER",button,"CENTER",(a[1]+b[1])/2-12,(a[2]+b[2])/2-12)
            t:SetRotation(math.atan2(dy,dx))
            art.glyphs[#art.glyphs+1]=t
        end
    end
    local function head(x,y)
        path({{x-2,y-2},{x-3,y},{x-2,y+2},{x,y+3},{x+2,y+2},{x+3,y},{x+2,y-2},{x,y-3},{x-2,y-2}})
    end
    if kind=="toggle" then
        path({{6,9},{12,15},{18,9}})
    elseif kind=="bag" then
        path({{5,5},{4,15},{6,18},{18,18},{20,15},{19,5},{5,5}})
        path({{8,18},{8,21},{16,21},{16,18}}) path({{5,14},{19,14}}) path({{12,13},{12,10}})
    elseif kind=="person" then
        head(12,17) path({{4,5},{5,9},{9,12},{15,12},{19,9},{20,5},{4,5}})
    elseif kind=="book" then
        path({{12,4},{9,6},{3,6},{3,20},{9,20},{12,18},{15,20},{21,20},{21,6},{15,6},{12,4},{12,18}})
    elseif kind=="tools" then
        path({{5,4},{18,19},{16,21},{20,17}}) path({{19,4},{6,19},{4,17},{8,21}})
    elseif kind=="tree" then
        path({{12,4},{12,20}}) path({{5,14},{5,10},{19,10},{19,14}})
        for _,x in ipairs({5,12,19}) do path({{x-2,15},{x-2,19},{x+2,19},{x+2,15},{x-2,15}}) end
    elseif kind=="medal" or kind=="gem" then
        path({{12,21},{20,14},{17,6},{7,6},{4,14},{12,21},{12,6}})
        if kind=="medal" then path({{7,6},{6,2},{12,5},{18,2},{17,6}}) end
    elseif kind=="quest" then
        path({{5,3},{19,3},{19,21},{5,21},{5,3}}) path({{12,17},{12,10}}) path({{12,7},{12,6}})
    elseif kind=="shield" then
        path({{4,20},{12,22},{20,20},{19,10},{16,6},{12,3},{8,6},{5,10},{4,20}}) path({{12,18},{12,7}})
    elseif kind=="people" or kind=="search" then
        head(9,17) path({{2,5},{3,9},{6,11},{12,11},{15,9},{16,5}})
        if kind=="people" then head(18,16) path({{17,10},{21,8},{22,5}})
        else path({{16,7},{16,12},{20,14},{23,11},{22,7},{18,6},{16,7}}) path({{22,7},{24,4}}) end
    elseif kind=="help" then
        path({{6,17},{8,20},{16,20},{19,17},{18,14},{12,11},{12,8}}) path({{12,5},{12,4}})
    elseif kind=="map" then
        path({{3,4},{3,19},{9,21},{15,18},{21,20},{21,5},{15,3},{9,6},{3,4}})
        path({{9,6},{9,21}}) path({{15,3},{15,18}})
    else
        for _,y in ipairs({6,12,18}) do path({{5,y},{19,y}}) end
    end
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
            surround:SetBackdropColor(.22,.23,.24,1)
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
        if not art then art=createSkin(button,glyphKind(button.GetName and button:GetName(),bag)) skins[button]=art end
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
