local _, SD = ...
local function plain(v)return not issecretvalue or not issecretvalue(v)end
local function tooltip(owner,title,lines)
    GameTooltip:SetOwner(owner,"ANCHOR_LEFT") GameTooltip:SetText(title)
    for _,line in ipairs(lines or {})do GameTooltip:AddLine(line,.75,.8,.85,true)end
    GameTooltip:Show()
end
function SD:CreateFieldNotes()
    if self.noteButtons or not self.panels then return end
    self.noteButtons={}
    local parent=self.panels.right
    local function add(key,tip,action)
        local b=CreateFrame("Button",nil,parent) self.noteButtons[key]=b
        b:SetFrameLevel(parent:GetFrameLevel()+4)
        b.label=b:CreateFontString(nil,"OVERLAY") b.label:SetFont("Fonts\\FRIZQT__.TTF",11,"") b.label:SetAllPoints() b.label:SetJustifyH("LEFT")
        b:SetScript("OnEnter",function() tooltip(b,tip,b.details) GameTooltip:AddLine("Click: "..SD:NoteActionLabel(key).." | Right-click: customize",.55,.65,.72,true)GameTooltip:Show()end)
        b:SetScript("OnLeave",function()GameTooltip:Hide()end)
        b:RegisterForClicks("LeftButtonUp","RightButtonUp")
        b:SetScript("OnClick",function(_,button)
            if InCombatLockdown() then SD.Print("Open this panel after combat.") return end
            SD:Run(tip,function()if button=="RightButton"then SD:OpenSettingsTab("notesCustomize")elseif key=="performance" and SD.oreRoute then SD:AdvanceOreRoute() else SD:DispatchNoteAction(key,action)end end)
        end)
    end
    add("zone","Location",function()if ToggleWorldMap then ToggleWorldMap()end end)
    add("bags","Inventory",function()if ToggleAllBags then ToggleAllBags()end end)
    add("durability","Equipment condition",function()if ToggleCharacter then ToggleCharacter("PaperDollFrame")end end)
    add("money","Gold & currencies",function()if ToggleCharacter then ToggleCharacter("TokenFrame")end end)
    add("clock","Calendar",function()if ToggleCalendar then ToggleCalendar()end end)
    add("performance","Connection & performance",function()SD:ShowReport()end)
    add("profile","Character profile",function()SD:ShowProfiles()end)
end
function SD:UpdateInfo()
    if not self.info or not self.db then return end
    self:CreateFieldNotes()
    for _,label in pairs(self.info)do label:Hide()end
    for _,button in pairs(self.noteButtons) do button:EnableMouse(not self.editing) end
    local g=self.geometry or self:GetGeometry()
    local step=math.min(17,math.max(12,(g.right.h-34-(g.utilityY+20.4+8))/4))
    local gathering, last, hint = self:GetGatheringNotes()
    if not gathering or not self.db.showInfo then
        if self.expeditionCard and not self.db.showInfo then self.expeditionCard:Hide() end
        if self.panels.right.caption then self.panels.right.caption:SetText("") end
    end
    local specs,signature={},{"compact-status"}
    local layoutKey=tostring(step)..":"..tostring(self.db.showInfo)..":"..table.concat(signature,",")
    if self.noteLayoutKey~=layoutKey then
        for _,button in pairs(self.noteButtons)do button:Hide()end
        for key,pos in pairs(specs)do
            local b=self.noteButtons[key]b:ClearAllPoints()b:SetPoint("TOPLEFT",self.panels.right,"TOPLEFT",18+pos[1],-38-pos[2]*17)
            b:SetSize(pos[3],step)b:SetShown(self.db.showInfo)
        end
        self.noteLayoutKey=layoutKey
    end
    if not self.db.showInfo then
        if self.commandStatus then self.commandStatus:Hide() self.commandMenuButton:Hide() self.commandExpeditionButton:Hide() end
        return
    end
    local n=self.noteButtons
    local zone=GetZoneText() or "Azeroth"
    local sub=GetSubZoneText and GetSubZoneText() or ""
    n.zone.label:SetText(sub~="" and sub or zone)
    local position
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local map=C_Map.GetBestMapForUnit("player")
        local p=map and C_Map.GetPlayerMapPosition(map,"player")
        if p then local x,y=p:GetXY() if plain(x) and plain(y)then position=string.format("Coordinates: %.1f, %.1f",x*100,y*100)end end
    end
    n.zone.details={zone,position or "Coordinates unavailable here.","Click to open the world map."}
    local free,total
    if not self.noteInventory or self.noteInventoryDirty then
    free,total=0,0
    if C_Container then
        for bag=0,NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 do
            local count,family=C_Container.GetContainerNumFreeSlots(bag)
            if family==0 then free=free+(count or 0) total=total+(C_Container.GetContainerNumSlots(bag)or 0)end
        end
    end
    self.noteInventory={free,total} self.noteInventoryDirty=nil
    else free,total=self.noteInventory[1],self.noteInventory[2] end
    n.bags.label:SetText(string.format("Bags: %d free / %d",free,total))
    n.bags.details={string.format("%d used of %d ordinary-bag slots",total-free,total),"Specialty bag capacity is excluded.","Click to toggle all bags."}
    local lowest,damaged,pieces
    if not self.noteDurability or self.noteDurabilityDirty then
    lowest,damaged,pieces=100,0,0
    if GetInventoryItemDurability then
        for slot=1,19 do local current,maximum=GetInventoryItemDurability(slot)
            if current and maximum and maximum>0 and plain(current) and plain(maximum)then
                pieces=pieces+1 local percent=current/maximum*100 lowest=math.min(lowest,percent)
                if current<maximum then damaged=damaged+1 end
            end
        end
    end
    self.noteDurability={lowest,damaged,pieces} self.noteDurabilityDirty=nil
    else lowest,damaged,pieces=unpack(self.noteDurability)end
    n.durability.label:SetText(pieces>0 and string.format("Durability: %d%%",lowest)or "Durability: --")
    n.durability.label:SetTextColor(lowest<30 and 1 or .73,lowest<30 and .35 or .79,lowest<30 and .25 or .83)
    n.durability.details={"Lowest equipped item durability.",tostring(damaged).." pieces need repair.","Click to inspect equipment."}
    local money=GetMoney()
    if plain(money)then
        money=money or 0 n.money.label:SetText(string.format("Gold: %d",math.floor(money/10000)))
        n.money.details={string.format("%dg %ds %dc",math.floor(money/10000),math.floor(money/100)%100,money%100),"Click to open currencies."}
    end
    n.clock.label:SetText(date("%I:%M %p")) n.clock.details={date("%A, %B %d"),"Local time. Click for the calendar."}
    local _,_,home,world=GetNetStats()
    n.performance.label:SetText(string.format("%d fps | %d ms",math.floor(GetFramerate()+.5),world or home or 0))
    n.performance.details={"Home latency: "..tostring(home).." ms","World latency: "..tostring(world).." ms","Click to open diagnostics."}
    local specName=self.itemSpecName or "Current spec"
    n.profile.label:SetText(specName.." | Profile") n.profile.details={"Per-character / per-spec preferences.","Click for profiles, snapshots and export."}
    self:RefreshCommandCenter()
    self:UpdateExpeditionCard(n.bags.label:GetText())
end

SD:On("BAG_UPDATE_DELAYED",function()SD.noteInventoryDirty=true end)
SD:On("PLAYER_EQUIPMENT_CHANGED",function()SD.noteDurabilityDirty=true end)
SD:On("UPDATE_INVENTORY_DURABILITY",function()SD.noteDurabilityDirty=true end)
SD:On("PLAYER_ENTERING_WORLD",function()SD.noteInventoryDirty=true SD.noteDurabilityDirty=true end)

function SD:RefreshCommandCenter()
    local parent=self.panels.right
    if not self.commandStatus then
        self.commandStatus=CreateFrame("Frame",nil,parent,"BackdropTemplate")
        self.commandStatus:SetFrameLevel(parent:GetFrameLevel()+3)
        self.commandStatus.line=self.commandStatus:CreateFontString(nil,"OVERLAY")
        self.commandStatus.line:SetFont("Fonts\\FRIZQT__.TTF",9,"")
        self.commandStatus.line:SetAllPoints() self.commandStatus.line:SetJustifyH("LEFT") self.commandStatus.line:SetWordWrap(false)
        local function button(caption,x,width,action)
            local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate,BackdropTemplate")
            b:SetFrameStrata("MEDIUM") b:SetFrameLevel(parent:GetFrameLevel()+5)
            b:SetPoint("TOPLEFT",x,-25) b:SetSize(width,18) b:SetText(caption)
            b:RegisterForClicks("LeftButtonUp") b:EnableMouse(true)
            b:SetScript("OnClick",function() if InCombatLockdown() then SD.Print("Open Command Center controls after combat.") return end SD:Run(caption,action) end)
            return b
        end
        self.commandExpeditionButton=button("Expedition",12,153,function()SD:OpenSettingsTab("gathering")end)
        self.commandMenuButton=button("Command menu",171,153,function()
            local menu=SD.commandMenu
            if menu and menu:IsShown() then menu:Hide() return end
            local create,H=SD:WindowBuilder("commandMenu")
            menu=create("Frame",nil,UIParent,"BackdropTemplate") SD.commandMenu=menu
            menu:SetSize(270,320) menu:SetPoint("BOTTOMRIGHT",SD.commandMenuButton,"TOPRIGHT",0,8)
            menu:SetFrameStrata("DIALOG") menu:SetClampedToScreen(true) SD:StyleCard(menu,true)
            H.text(menu,"TOOLS",15,14,-14,240):SetTextColor(SD:CardAccent())
            for i,entry in ipairs({{"gathering","Expedition & fishing"},{"readiness","Readiness"},{"session","Session statistics"},{"waypoints","Saved locations"},{"quests","Quest notebook"},{"profiles","Profiles & backups"},{"master","Settings"}}) do
                H.button(menu,entry[2],12,-43-(i-1)*38,246,function()menu:Hide() SD:OpenSettingsTab(entry[1])end)
            end
        end)
    end
    self.commandStatus:ClearAllPoints() self.commandStatus:SetPoint("TOPLEFT",parent,"TOPLEFT",12,-7)
    self.commandStatus:SetSize(self.geometry.right.w-24,14) self.commandStatus:SetBackdrop(nil) self.commandStatus:Show()
    local condition=self.noteDurability and self.noteDurability[1] or 100
    local gold=GetMoney() if not plain(gold) then gold=0 end
    local _,_,home,world=GetNetStats()
    self.commandStatus.line:SetText(string.format("%d%% gear | %dg | %s | %d fps / %d ms",condition,math.floor((gold or 0)/10000),date("%I:%M %p"),math.floor(GetFramerate()+.5),world or home or 0))
    self.commandStatus.line:SetTextColor(.80,.80,.76)
    self.commandMenuButton:Show() self.commandExpeditionButton:Show()
    self.commandMenuButton:EnableMouse(not self.editing) self.commandExpeditionButton:EnableMouse(not self.editing)
    self:StyleAction(self.commandMenuButton) self:StyleAction(self.commandExpeditionButton)
    parent.caption:SetText("")
end
SD:On("PLAYER_REGEN_DISABLED",function()if SD.commandMenu then SD.commandMenu:Hide()end end)
SD:On("GLOBAL_MOUSE_DOWN",function(button)
    local menu=SD.commandMenu
    if button=="LeftButton" and menu and menu:IsShown() and MouseIsOver and not MouseIsOver(menu) and not MouseIsOver(SD.commandMenuButton) then menu:Hide() end
end)
