local _, SD = ...

-- A launcher's replacement SetPoint/SetParent methods may call themselves when
-- another addon takes ownership. Use clean widget methods for drawer placement.
local prototype=CreateFrame("Button")
prototype:Hide()
local nativeButtonMethods={}
for _,method in ipairs({"SetParent","SetScale","SetFrameStrata","SetFrameLevel","SetSize","ClearAllPoints","SetPoint","SetScript"}) do
    nativeButtonMethods[method]=prototype[method]
end
local function nativeSet(button,method,...)
    return nativeButtonMethods[method](button,...)
end

local function snapshot(button)
    local saved={parent=button:GetParent(),scale=button:GetScale(),
        w=button:GetWidth(),h=button:GetHeight(),points={},
        strata=button:GetFrameStrata(),level=button:GetFrameLevel(),
        dragStart=button:GetScript("OnDragStart"),dragStop=button:GetScript("OnDragStop")}
    for i=1,button:GetNumPoints() do saved.points[i]={button:GetPoint(i)} end
    return saved
end

local function collectButtons(self)
    if InCombatLockdown() or not self.adeptMapActive then return end
    local buttons,seen={},{}
    local native={}
    local function exclude(frame) if frame then native[frame]=true end end
    for _,name in ipairs({"GameTimeFrame","TimeManagerClockButton","MiniMapTracking",
        "MiniMapMailFrame","MiniMapWorldMapButton","QueueStatusMinimapButton",
        "ExpansionLandingPageMinimapButton","MinimapZoomIn","MinimapZoomOut"}) do exclude(_G[name]) end
    local cluster=MinimapCluster
    exclude(cluster and cluster.ZoneTextButton)
    exclude(cluster and cluster.Tracking and cluster.Tracking.Button)
    exclude(Minimap and Minimap.ZoomIn)
    exclude(Minimap and Minimap.ZoomOut)
    exclude(self.adeptMapToggle)
    local function add(button,registered)
        if not button or seen[button] or native[button] or not button.GetName then return end
        if button.IsForbidden and button:IsForbidden() then return end
        local name=button:GetName()
        if not name or not button:IsObjectType("Button") then return end
        local lower=name:lower()
        local launcher=registered or name:match("^LibDBIcon10_")
            or lower:find("minimapbutton",1,true) or lower:find("minimapicon",1,true)
            or (type(button.dataObject)=="table" and button.dataObject.type=="launcher")
        if not launcher then return end
        if not registered and (lower:find("pin",1,true) or lower:find("node",1,true)
            or lower:find("marker",1,true) or lower:find("questicon",1,true)) then return end
        if not button:IsShown() and not self.adeptMapButtons[button] then return end
        seen[button]=true
        buttons[#buttons+1]=button
    end
    self.adeptMapCollectStage="Read registered addon launchers"
    local lib=LibStub and LibStub("LibDBIcon-1.0",true)
    if lib and lib.GetButtonList and lib.GetMinimapButton then
        for _,name in ipairs(lib:GetButtonList()) do add(lib:GetMinimapButton(name),true) end
    end
    for _,parent in pairs({Minimap,cluster,cluster and cluster.MinimapContainer,MinimapBackdrop}) do
        if parent and parent.GetChildren then
            for _,child in ipairs({parent:GetChildren()}) do add(child) end
        end
    end
    for button in pairs(self.adeptMapButtons) do add(button) end
    table.sort(buttons,function(a,b)return a:GetName()<b:GetName()end)
    local columns=math.min(6,math.max(1,#buttons))
    self.adeptMapDrawer:SetSize(columns*36+16,math.max(1,math.ceil(#buttons/columns))*36+16)
    for i,button in ipairs(buttons) do
        self.adeptMapCollectStage="Place "..button:GetName()
        if not self.adeptMapButtons[button] then
            self.adeptMapButtons[button]=snapshot(button)
            nativeSet(button,"SetScript","OnDragStart",nil)
            nativeSet(button,"SetScript","OnDragStop",nil)
        end
        local x,y=10+((i-1)%columns)*36,-10-math.floor((i-1)/columns)*36
        local point,relative,_,oldX,oldY=button:GetPoint(1)
        if button:GetParent()~=self.adeptMapDrawer or point~="TOPLEFT"
            or relative~=self.adeptMapDrawer or oldX~=x or oldY~=y or button:GetWidth()~=30 then
            nativeSet(button,"SetParent",self.adeptMapDrawer)
            nativeSet(button,"SetScale",1)
            nativeSet(button,"SetFrameStrata","DIALOG")
            nativeSet(button,"SetFrameLevel",self.adeptMapDrawer:GetFrameLevel()+2)
            nativeSet(button,"SetSize",30,30)
            nativeSet(button,"ClearAllPoints")
            nativeSet(button,"SetPoint","TOPLEFT",self.adeptMapDrawer,"TOPLEFT",x,y)
        end
    end
    self.adeptMapToggle.label:SetText("ADDONS  "..#buttons)
end

function SD:CollectAdeptMapButtons()
    if self.adeptMapCollecting then return end
    self.adeptMapCollecting=true
    local ok,err=xpcall(function() collectButtons(self) end,function(message)
        local stack=debugstack and debugstack(2,12,0) or (debug and debug.traceback and debug.traceback() or "")
        return tostring(self.adeptMapCollectStage or "Collect launchers")..": "..tostring(message).."\n"..stack
    end)
    self.adeptMapCollecting=nil
    self.adeptMapCollectStage=nil
    if not ok then self:ReportError("Addon icon drawer",err) end
end

local function refreshMinimap(self)
    if not Minimap or InCombatLockdown() then return end
    local active=self.db and self.db.enabled and self.layoutName=="Adept" and self:IsOurLayoutActive()
    self.adeptMapActive=active
    if not active then
        if self.adeptMapSaved then
            Minimap:SetMaskTexture(self.adeptMapSaved.mask)
            if GetMinimapShape==self.adeptSquareShape then GetMinimapShape=self.adeptMapSaved.shape end
            for region,alpha in pairs(self.adeptMapSaved.alphas) do region:SetAlpha(alpha) end
            for button,saved in pairs(self.adeptMapButtons or {}) do
                nativeSet(button,"SetParent",saved.parent)
                nativeSet(button,"SetScale",saved.scale)
                nativeSet(button,"SetSize",saved.w,saved.h)
                nativeSet(button,"SetFrameStrata",saved.strata)
                nativeSet(button,"SetFrameLevel",saved.level)
                nativeSet(button,"ClearAllPoints")
                for _,point in ipairs(saved.points) do nativeSet(button,"SetPoint",unpack(point)) end
                nativeSet(button,"SetScript","OnDragStart",saved.dragStart)
                nativeSet(button,"SetScript","OnDragStop",saved.dragStop)
            end
            for button,saved in pairs(self.adeptMapNativeControls or {}) do
                button:SetScale(saved.scale)
                button:SetSize(saved.w,saved.h)
                button:ClearAllPoints()
                for _,point in ipairs(saved.points) do button:SetPoint(unpack(point)) end
            end
            self.adeptMapNativeControls=nil
            self.adeptMapSaved=nil
            self.adeptMapButtons={}
        end
        if self.adeptMapBorder then self.adeptMapBorder:Hide() end
        if self.adeptMapDrawer then self.adeptMapDrawer:Hide() end
        return
    end
    if not self.adeptMapBorder then
        local border=CreateFrame("Frame",nil,Minimap,"BackdropTemplate")
        self.adeptMapBorder=border
        border:EnableMouse(false)
        border:SetPoint("TOPLEFT",Minimap,"TOPLEFT",-3,3)
        border:SetPoint("BOTTOMRIGHT",Minimap,"BOTTOMRIGHT",3,-3)
        border:SetFrameLevel(Minimap:GetFrameLevel()+2)
        border:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        border:SetBackdropBorderColor(.72,.64,.45,1)
        local header=CreateFrame("Frame",nil,border,"BackdropTemplate")
        header:SetPoint("BOTTOMLEFT",border,"TOPLEFT",0,0)
        header:SetPoint("BOTTOMRIGHT",border,"TOPRIGHT",0,0)
        header:SetHeight(40)
        border.header=header
        header:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
        header:SetBackdropColor(.13,.135,.14,1)
        border.zone=header:CreateFontString(nil,"OVERLAY")
        border.zone:SetFont("Fonts\\FRIZQT__.TTF",11,"")
        border.zone:SetPoint("TOPLEFT",8,-4)
        border.zone:SetWidth(120)
        border.zone:SetWordWrap(false)
        border.zone:SetJustifyH("LEFT")
        local toggle=CreateFrame("Button",nil,header)
        self.adeptMapToggle=toggle
        toggle:SetPoint("TOPRIGHT",-4,0)
        toggle:SetSize(72,22)
        toggle.label=toggle:CreateFontString(nil,"OVERLAY")
        toggle.label:SetAllPoints()
        toggle.label:SetFont("Fonts\\ARIALN.TTF",10,"")
        toggle.label:SetTextColor(.88,.8,.61)
        local drawer=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
        self.adeptMapDrawer=drawer
        drawer:SetFrameStrata("DIALOG")
        drawer:SetPoint("BOTTOM",border,"TOP",0,32)
        drawer:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1,tile=true,tileSize=32})
        drawer:SetBackdropBorderColor(.72,.64,.45,1)
        drawer:Hide()
        toggle:SetScript("OnClick",function()
            if InCombatLockdown() then SD.Print("Open or close the addon drawer after combat.") return end
            SD:CollectAdeptMapButtons()
            drawer:SetShown(not drawer:IsShown())
        end)
        toggle:SetScript("OnEnter",function(owner)
            GameTooltip:SetOwner(owner,"ANCHOR_LEFT")
            GameTooltip:SetText("Addon icons")
            GameTooltip:AddLine("Click to open or close the drawer.",.8,.8,.75,true)
            GameTooltip:Show()
        end)
        toggle:SetScript("OnLeave",function() GameTooltip:Hide() end)
        self:RegisterUsageButton(toggle,"Addon drawer")
    end
    self.adeptMapButtons=self.adeptMapButtons or {}
    if not self.adeptMapSaved then
        self.adeptMapSaved={mask=Minimap.GetMaskTexture and Minimap:GetMaskTexture() or "Textures\\MinimapMask",
            shape=GetMinimapShape,alphas={}}
        self.adeptSquareShape=self.adeptSquareShape or function()return "SQUARE"end
        GetMinimapShape=self.adeptSquareShape
    end
    Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
    for _,region in pairs({MinimapCompassTexture,MinimapCompassTextureUnderlay,MinimapBorder,
        MinimapBorderTop,MinimapZoneText,MinimapCluster and MinimapCluster.ZoneTextButton}) do
        if self.adeptMapSaved.alphas[region]==nil then self.adeptMapSaved.alphas[region]=region:GetAlpha() end
        region:SetAlpha(0)
    end
    if self.mapCaption then self.mapCaption:Hide() end
    if self.mapRim then self.mapRim:Hide() end
    if self.gulveigZonePlate then self.gulveigZonePlate:Hide() end
    -- Keep native map tools in a single header row, with their original anchors restored on exit.
    self.adeptMapNativeControls=self.adeptMapNativeControls or {}
    local g=self:GetGeometry()
    self.adeptMapDrawer:SetScale(g.scale*g.density)
    -- Move Tracking as a unit: its Background belongs to the container, not Button.
    local controls={
        {frame=(MinimapCluster and MinimapCluster.Tracking) or MiniMapTracking},
        {frame=GameTimeFrame},{frame=TimeManagerClockButton},{frame=MiniMapWorldMapButton},
    }
    local offset=6
    for _,entry in ipairs(controls) do
        local button=entry.frame
        if button then
            if not self.adeptMapNativeControls[button] then self.adeptMapNativeControls[button]=snapshot(button) end
            local saved=self.adeptMapNativeControls[button]
            local parent=button:GetParent() or UIParent
            local width=button==TimeManagerClockButton and 52 or 18
            local artW,artH=saved.w,saved.h
            if button.GetRegions then
                for _,region in ipairs({button:GetRegions()}) do
                    if region.GetWidth and region.GetHeight then
                        artW=math.max(artW,region:GetWidth())
                        artH=math.max(artH,region:GetHeight())
                    end
                end
            end
            local fit=math.min(width/math.max(1,artW),18/math.max(1,artH))
            -- Native day/night textures have fixed dimensions: scale the complete
            -- control instead of shrinking its hit rectangle underneath the art.
            button:SetSize(saved.w,saved.h)
            button:SetScale(.8*g.scale*g.density*fit*UIParent:GetEffectiveScale()/parent:GetEffectiveScale())
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT",self.adeptMapBorder.header,"TOPLEFT",offset/fit,-21/fit)
            offset=offset+width+6
        end
    end
    self.adeptMapBorder:Show()
    self.adeptMapBorder.zone:SetWidth(math.max(40,Minimap:GetWidth()-88))
    self.adeptMapBorder.zone:SetText((GetMinimapZoneText and GetMinimapZoneText()) or GetZoneText())
    self:CollectAdeptMapButtons()
end

function SD:RefreshAdeptMinimap()
    if self.adeptMapBusy then return end
    self.adeptMapBusy=true
    local ok,err=pcall(refreshMinimap,self)
    self.adeptMapBusy=nil
    if not ok then self:ReportError("Adept minimap",err) end
end

local queued
local function refresh()
    if queued then return end
    queued=true
    C_Timer.After(.4,function()
        queued=nil
        if SD.db then SD:RefreshAdeptMinimap() end
    end)
end
SD:On("ADDON_LOADED",refresh)
SD:On("PLAYER_ENTERING_WORLD",refresh)
SD:On("ZONE_CHANGED",refresh)
SD:On("ZONE_CHANGED_INDOORS",refresh)
SD:On("PLAYER_REGEN_ENABLED",refresh)
SD:On("GLOBAL_MOUSE_DOWN",function()
    local drawer=SD.adeptMapDrawer
    if not InCombatLockdown() and drawer and drawer:IsShown() and MouseIsOver
        and not MouseIsOver(drawer) and not MouseIsOver(SD.adeptMapToggle) then drawer:Hide() end
end)
