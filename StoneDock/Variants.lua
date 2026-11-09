local _, SD = ...

local names={stone="StoneDock - Dark Stone",gulveig="Gulveig Bar"}

local function variant(name)

    for key,value in pairs(names) do if value==name then return key end end

end



function SD:InitializeLayoutVariant()

    local active=self:GetActiveLayout()

    local key=active and variant(active.layoutName) or self.db.layoutVariant

    if not names[key] then key="stone" end

    self.db.layoutVariant=key

    self.layoutName=names[key]

end



-- Never share native unit/aura/tracking anchors between the two designs.

function SD:GetVariantProfileStore()

    if self.layoutName~=names.gulveig then return self.profile,"native" end

    self.profile.variantNative=self.profile.variantNative or {}

    return self.profile.variantNative,"gulveig"

end



function SD:ActivateLayoutVariant(key)

    if not names[key] or self:IsBusy() then return false end

    local oldName=self.layoutName

    if self.CaptureProfile then self:CaptureProfile() end

    self.variantSwitching=true

    self.layoutName=names[key]

    local ok,err=pcall(self.ActivateLayout,self)

    self.variantSwitching=nil

    if not ok or not self:IsOurLayoutActive() then

        self.layoutName=oldName self.db.layoutVariant=variant(oldName) or "stone"

        if not ok then self:ReportError("Switch layout",err) end

        return false

    end

    self.db.layoutVariant=key

    -- Each native layout already owns its saved anchors. Do not restore the

    -- other design's character profile or geometry over them when switching.

    self.db.nativeGeometry=nil

    self.profileNeedsRestore=nil

    self:CaptureProfile()

    self:RefreshPanels()

    return true

end



SD:On("EDIT_MODE_LAYOUTS_UPDATED",function()

    if not SD.db or SD.layoutWriteBusy or SD.variantSwitching then return end

    local active=SD:GetActiveLayout()

    local key=active and variant(active.layoutName)

    if key and SD.layoutName~=names[key] then

        SD.layoutName=names[key] SD.db.layoutVariant=key

        SD.db.nativeGeometry=nil SD.profileNeedsRestore=nil

    end

end)



function SD:GetGulveigGeometry(width,height,rise)

    local scale=width/1920

    local dx,dy=self.db.barOffsetX,self.db.barOffsetY

    local stretch=self.db.barWidth/100

    local compact=.8

    local function r(x,y,w,h)return {x=x,y=y*rise,w=w,h=h*rise}end

    return {

        variant="gulveig",revision=6,width=width,height=height,scale=scale,density=rise,screenHeight=height/scale,

        base=r(0,0,1920,1),left=r(20,90,420,160),right=r(1440,300,440,160),

        leftWell=r(40,250,440,20),rightWell=r(1440,250,440,20),

        map=r(1640,22,250,260),chat=r(30,100,400,135),

        menuDrawer=r(25,4,410,38),bagDrawer=r(25,47,410,36),utilityY=260*rise,

        bars={

            {index=1,x=960+dx,y=(24+(241-24)*compact+dy)*rise,icons=6,iconSize=58*compact*stretch*rise},

            {index=2,x=960+dx,y=(24+(156-24)*compact+dy)*rise,icons=8,iconSize=70*compact*stretch*rise},

            {index=3,x=960+dx,y=(24+(75-24)*compact+dy)*rise,icons=6,iconSize=58*compact*stretch*rise},

        },

        ornament=r(510+dx,24+dy,900*compact*stretch,270*compact),

        trackingWell=r(576,-100,768,115),

        auxLeft=r(770+dx,258+dy,180,20),auxRight=r(970+dx,258+dy,180,20),

        player={x=580,y=345*rise},target={x=1340,y=345*rise},

        cast={x=-540,y=370*rise},party={x=40,y=300*rise},raid={x=40,y=370*rise},

    }

end



function SD:FinishGulveigLayout(layout,g,fresh)

    local H,E=self.UnitLayoutHelpers,Enum.EditModeSystem

    if not H then return end

    local s,U=g.scale,Enum.EditModeUnitFrameSystemIndices

    local function anchor(system,index,point,relative,x,y)

        H.anchor(H.find(layout,system,index),point,relative,x*s,y*s)

    end

    if self.db.arrangeUtility then

        anchor(E.StatusTrackingBar,1,"BOTTOM","BOTTOM",0,5*g.density)

        anchor(E.StatusTrackingBar,2,"BOTTOM","BOTTOM",0,18*g.density)

    end

    for _,entry in ipairs({{11,g.auxLeft,"BOTTOMRIGHT"},{12,g.auxRight,"BOTTOMLEFT"},{13,g.auxRight,"BOTTOMLEFT"}}) do

        local well=entry[2]

        anchor(E.ActionBar,entry[1],entry[3],"BOTTOMLEFT",well.x+(entry[1]==11 and well.w-12 or 12),well.y+well.h-18*g.density)

    end

    if fresh and self.db.arrangeUnits then

        local player=H.find(layout,E.UnitFrame,U.Player)

        H.setting(player,Enum.EditModeUnitFrameSetting.CastBarUnderneath,1)

        anchor(E.UnitFrame,U.Pet,"TOPLEFT","BOTTOMLEFT",240,365*g.density)

        anchor(E.UnitFrame,U.Focus,"BOTTOMRIGHT","BOTTOMLEFT",1700,550*g.density)

    end

    if fresh then

        anchor(E.CastBar,nil,"BOTTOM","BOTTOM",g.cast.x,g.cast.y)

    end

end



function SD:RefreshVariantArt(g)

    local gulveig=g.variant=="gulveig"

    for _,key in ipairs({"base","leftWell","rightWell","map","right","menuDrawer","bagDrawer"}) do

        self.panels[key]:SetShown(not gulveig)

    end

    local chat=self.panels.left

    -- Suppress the native chat fill too when styling is opted out.

    self.nativeChatAlphas=self.nativeChatAlphas or {}

    for _,region in pairs({ChatFrame1 and ChatFrame1.Background,_G.ChatFrame1Background}) do

        if region and region.GetAlpha then

            if gulveig and not self.db.chatStyle then

                if self.nativeChatAlphas[region]==nil then self.nativeChatAlphas[region]=region:GetAlpha() end

                region:SetAlpha(0)

            elseif self.nativeChatAlphas[region]~=nil then

                region:SetAlpha(self.nativeChatAlphas[region]) self.nativeChatAlphas[region]=nil

            end

        end

    end

    if not self.gulveigChatTrim then

        self.gulveigChatTrim=chat:CreateTexture(nil,"OVERLAY")

        self.gulveigChatTrim:SetAllPoints()

        self.gulveigChatTrim:SetTexture("Interface\\AddOns\\StoneDock\\Media\\GulveigChat.tga")

    end

    chat:SetShown(not gulveig or self.db.chatStyle==true)

    self.gulveigChatTrim:SetShown(false)
    if not self.gulveigChatBorder then
        self.gulveigChatBorder=self:CreateGulveigBorder(chat)
        self.gulveigChatBorder:SetAllPoints(chat)
    end
    self.gulveigChatBorder:SetShown(gulveig and self.db.chatStyle==true)

    for _,texture in ipairs(chat.trim) do texture:SetShown(not gulveig) end

    for _,texture in ipairs(chat.rivets) do texture:SetShown(not gulveig) end

    chat.fill:ClearAllPoints()

    if gulveig then

        if ChatFrame1 then

            -- Two native anchors follow movement, size and UI scale directly;

            -- never poll geometry or modify the protected/native chat frame.

            chat:ClearAllPoints()

            chat:SetPoint("TOPLEFT",ChatFrame1,"TOPLEFT",-22,30)

            chat:SetPoint("BOTTOMRIGHT",ChatFrame1,"BOTTOMRIGHT",22,-24)

        end

        chat.fill:SetPoint("TOPLEFT",chat,"TOPLEFT",14,-14)

        chat.fill:SetPoint("BOTTOMRIGHT",chat,"BOTTOMRIGHT",-14,14)

        chat.fill:SetColorTexture(0,0,0,.75)

        chat.shadow:Hide()

    else chat.fill:SetAllPoints(chat) chat.shadow:Show() end

    self:RefreshGulveigTrackingArt(gulveig and self.db.enabled and self:IsOurLayoutActive())
    if not gulveig and not self.gulveigBacking then return end
    if not self.gulveigBacking then
        self.gulveigBacking=CreateFrame("Frame",nil,UIParent)
        self.gulveigBacking:SetFrameStrata("BACKGROUND")
        self.gulveigBacking:EnableMouse(false)
        local backing=self.gulveigBacking
        self.gulveigArt=backing:CreateTexture(nil,"ARTWORK")
        self.gulveigArt:SetTexture("Interface\\AddOns\\StoneDock\\Media\\GulveigBarV2.tga")
        self.gulveigFills={}
        for i=1,2 do
            local fill=backing:CreateTexture(nil,"BACKGROUND")
            fill:SetColorTexture(0,0,0,1)
            self.gulveigFills[i]=fill
        end
    end
    local backing=self.gulveigBacking
    backing:SetPoint("BOTTOM",UIParent,"BOTTOM",0,0)
    backing:SetSize(1920,g.screenHeight)
    backing:SetScale(g.scale)
    backing:SetAlpha(self.currentUIAlpha or 1)
    backing:SetShown(gulveig and self.db.enabled and (self:IsOurLayoutActive() or self.db.showGuides))
    if not gulveig then return end

    local ornament=g.ornament
    self.gulveigArt:ClearAllPoints()
    self.gulveigArt:SetPoint("BOTTOM",backing,"BOTTOMLEFT",g.bars[1].x,ornament.y)
    self.gulveigArt:SetSize(ornament.w,ornament.h)

    -- Two overlapping fills cover the openings while leaving the outer wings transparent.
    local centerFill,middleFill=unpack(self.gulveigFills)
    centerFill:SetPoint("CENTER",self.gulveigArt,"CENTER",0,0)
    centerFill:SetSize(ornament.w*.46,ornament.h*.84)
    middleFill:SetPoint("CENTER",self.gulveigArt,"CENTER",0,-ornament.h*.01)
    middleFill:SetSize(ornament.w*.73,ornament.h*.35)
end

function SD:ChooseFirstLayout(key)

    if not self:ActivateLayoutVariant(key) then return false end

    StoneDockCharDB.welcomed=true

    self.welcomePending=nil

    if self.layoutChooser then self.layoutChooser:Hide() end

    SD.Print("Layout ready. Change layouts anytime in Theme & layout.")

    return true

end



function SD:PromptForLayout()

    if StoneDockCharDB.welcomed then return end

    if self:IsBusy() then self.welcomePending=true return end

    self.welcomePending=nil

    if not self.layoutChooser then

        local create,H=self:WindowBuilder("layoutChooser")

        local f=create("Frame","StoneDockLayoutChooser",UIParent,"BackdropTemplate")

        self.layoutChooser=f

        f:SetSize(560,330) f:SetPoint("CENTER") f:SetFrameStrata("DIALOG")

        f:SetClampedToScreen(true) self:StyleCard(f,false)

        H.text(f,"Welcome to StoneDock",23,24,-24,510)

        H.text(f,"Choose your starting layout",15,24,-66,510)

        H.text(f,"StoneDock dashboard: split action banks, centered map and a tools panel.\n\nGulveig Bar: Celtic trim, three centered action rows, flanking unit frames and a bottom-right map.",13,24,-100,510)

        f.selection=self.db.layoutVariant or "stone"

        f.choice=self:SettingsDropdown(f,"Layout",{{"stone","StoneDock dashboard"},{"gulveig","Gulveig Bar"}},

            function()return f.selection end,function(key)f.selection=key end,create)

        f.choice:SetPoint("TOPLEFT",24,-218)

        f.apply=H.button(f,"Use this layout",24,-272,248,function()SD:ChooseFirstLayout(f.selection)end)

        f.later=H.button(f,"Decide later",288,-272,248,function()f:Hide()end)

        UISpecialFrames[#UISpecialFrames+1]="StoneDockLayoutChooser"

    end

    self.layoutChooser:Show()

end



SD:On("PLAYER_REGEN_ENABLED",function()if SD.welcomePending then SD:PromptForLayout() end end)



-- Hide only these native controls, outside combat, and restore their former

-- visibility when leaving Gulveig. No parenting or secure attributes change.

function SD:RefreshVariantControls()

    if InCombatLockdown() or self.variantControlsBusy then return end

    self.variantControlsBusy=true

    local hide=self.db.enabled and self.layoutName==names.gulveig and self:IsOurLayoutActive() and not self.editing

    self.variantHiddenControls=self.variantHiddenControls or {}

    self.variantControlHooks=self.variantControlHooks or {}

    for _,frame in ipairs({MicroMenuContainer or MicroMenu,BagsBar}) do

        if not self.variantControlHooks[frame] and frame.HookScript then

            frame:HookScript("OnShow",function()SD:RefreshVariantControls()end)

            self.variantControlHooks[frame]=true

        end

        if hide then

            if self.variantHiddenControls[frame]==nil then self.variantHiddenControls[frame]=frame:IsShown() end

            if frame:IsShown() then frame:Hide() end

        elseif self.variantHiddenControls[frame]~=nil then

            local shown=self.variantHiddenControls[frame]

            self.variantHiddenControls[frame]=nil

            if shown then frame:Show() end

        end

    end

    self.variantControlsBusy=nil

end



function SD:GetGulveigChatBounds(g)

    g=g or self:GetGeometry()

    if ChatFrame1 and ChatFrame1.GetRect then

        local x,y,w,h=ChatFrame1:GetRect()

        if x and y and w and h then

            local factor=ChatFrame1:GetEffectiveScale()/UIParent:GetEffectiveScale()/g.scale

            return {x=x*factor,y=y*factor,w=w*factor,h=h*factor}

        end

    end

    return g.chat

end



function SD:RefreshChatGroupLayout()

    if not self.db or self.layoutName~=names.gulveig or not self.db.arrangeGroups or not self:IsOurLayoutActive() then return end

    if self:IsBusy() or self.layoutWriteBusy then self.chatGroupDeferred=true return end

    if self.chatGroupBusy then return end

    self.chatGroupBusy=true

    local ok,err=pcall(function()

        local full=self:GetFullLayouts() if not full then return end

        local layout=full.layouts[full.activeLayout]

        local info=self.UnitLayoutHelpers.find(layout,Enum.EditModeSystem.UnitFrame,Enum.EditModeUnitFrameSystemIndices.Party)

        local before=SD.Copy(info)

        self:ConfigureNativeParty(info)

        if not SD.Equal(before,info) then self:SaveAndRefreshLayout(full,full.activeLayout) end

        self:QueueRaidSplit()

        self.chatGroupDeferred=nil

    end)

    self.chatGroupBusy=nil

    if not ok then self:ReportError("Align groups above chat",err) end

end



function SD:QueueChatGroupLayout()

    if not self.db or self.layoutName~=names.gulveig or self.chatGroupBusy or self.chatGroupQueued then return end

    self.chatGroupQueued=true

    C_Timer.After(.35,function()

        SD.chatGroupQueued=nil

        SD:RefreshChatGroupLayout()

    end)

end



function SD:InstallChatGroupHooks()

    if not ChatFrame1 or self.chatGroupHooked then return end

    self.chatGroupHooked=true

    ChatFrame1:HookScript("OnSizeChanged",function() SD:QueueChatGroupLayout() end)

    ChatFrame1:HookScript("OnDragStop",function() SD:QueueChatGroupLayout() end)

    if hooksecurefunc and type(FCF_SavePositionAndDimensions)=="function" then

        hooksecurefunc("FCF_SavePositionAndDimensions",function(frame)

            if frame==ChatFrame1 then SD:QueueChatGroupLayout() end

        end)

    end

end

SD:On("PLAYER_LOGIN",function()SD:InstallChatGroupHooks()end)

SD:On("PLAYER_REGEN_ENABLED",function()if SD.chatGroupDeferred then SD:QueueChatGroupLayout()end end)

