local _, SD = ...
local LIMIT=1000
local hooks=setmetatable({}, {__mode="k"})
local eventFrame
local windows={
    {"CharacterFrame","Character"},{"SpellBookFrame","Spellbook"},{"PlayerTalentFrame","Talents"},
    {"SkillFrame","Skills"},{"FriendsFrame","Social"},{"PVEFrame","Group finder"},
    {"LFGListFrame","Group finder list"},{"QuestLogFrame","Quest log"},{"WorldMapFrame","World map"},
    {"MerchantFrame","Merchant"},{"GossipFrame","NPC dialogue"},{"BankFrame","Bank"},
    {"AuctionHouseFrame","Auction house"},{"ContainerFrameCombinedBags","Combined bags"},
    {"Questie_BaseFrame","Questie"},{"NaowhForeverThreatMeter","Naowh threat meter"},
    {"StoneDockSettings","StoneDock settings"},
}
for i=1,13 do windows[#windows+1]={"ContainerFrame"..i,"Bag window "..i} end
local function clean(value,limit)
    if type(value)~="string" or (issecretvalue and issecretvalue(value)) then return "" end
    return value:gsub("[%c]"," "):sub(1,limit or 100)
end
local function now() return GetTime and GetTime() or 0 end
function SD:IsUsageRecording()
    return self.usageSession and self.usageSession.active or false
end
function SD:RecordUsage(kind,detail)
    local s=self.usageSession
    if not s or not s.active then return end
    kind,detail=clean(kind,40),clean(detail,140)
    local instance="none"
    if IsInInstance then
        local _,value=IsInInstance()
        if value=="party" or value=="raid" or value=="pvp" or value=="arena" then instance=value end
    end
    local event={t=math.max(0,now()-s.started),kind=kind,detail=detail,
        combat=not not InCombatLockdown(),layout=clean(self.layoutName or "unknown",50),
        group=GetNumGroupMembers and GetNumGroupMembers() or 0,instance=instance,
        width=UIParent:GetWidth(),height=UIParent:GetHeight(),scale=UIParent:GetEffectiveScale()}
    s.events[s.next]=event
    s.next=s.next%LIMIT+1
    s.count=math.min(LIMIT,s.count+1)
    s.total=s.total+1 s.elapsed=event.t
    s.counts[kind]=(s.counts[kind] or 0)+1
end
function SD:WatchUsageWindows(initial)
    if not self:IsUsageRecording() or InCombatLockdown() then return end
    for _,spec in ipairs(windows) do
        local frame=_G[spec[1]]
        if frame and not hooks[frame] then
            local ok=pcall(function()
                if frame.IsForbidden and frame:IsForbidden() then return end
                if type(frame.HookScript)~="function" or type(frame.IsShown)~="function" then return end
                local label=spec[2]
                frame:HookScript("OnShow",function() SD:RecordUsage("window_open",label) end)
                frame:HookScript("OnHide",function() SD:RecordUsage("window_close",label) end)
                hooks[frame]=true
                if frame:IsShown() then SD:RecordUsage(initial and "window_initial" or "window_available",label) end
            end)
            if not ok then self:RecordUsage("window_unavailable",spec[2]) end
        elseif frame and initial and frame.IsShown and frame:IsShown() then
            self:RecordUsage("window_initial",spec[2])
        end
    end
end
function SD:RegisterUsageButton(button,label)
    if not button or button.stoneDockUsageHook then return end
    button.stoneDockUsageHook=true
    label=clean(label,100)
    button:HookScript("OnClick",function(_,mouse,down)
        if not down then SD:RecordUsage("action",label..(mouse=="RightButton" and " [right-click]" or "")) end
    end)
end
function SD:StartUsageRecording()
    if self:IsUsageRecording() then SD.Print("Usage recording is already running.") return end
    if self:IsBusy() then SD.Print("Start usage recording outside combat and Edit Mode.") return end
    if StoneDockCharDB.usageRecorder then StoneDockCharDB.usageRecorderPrevious=StoneDockCharDB.usageRecorder end
    local s={version=1,addonVersion=self.version,started=now(),active=true,events={},next=1,count=0,total=0,elapsed=0,counts={}}
    self.usageSession=s StoneDockCharDB.usageRecorder=s
    if not eventFrame then
        eventFrame=CreateFrame("Frame")
        eventFrame:SetScript("OnEvent",function(_,event)
            if event=="ADDON_LOADED" then SD:WatchUsageWindows(false)
            elseif event=="PLAYER_LOGOUT" then SD:StopUsageRecording(true)
            else
                SD:RecordUsage("context",event)
                if event=="PLAYER_REGEN_ENABLED" then SD:WatchUsageWindows(false) end
            end
        end)
    end
    for _,event in ipairs({"PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","GROUP_ROSTER_UPDATE",
        "PLAYER_ENTERING_WORLD","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED","ADDON_LOADED","PLAYER_LOGOUT"}) do eventFrame:RegisterEvent(event) end
    self:RecordUsage("record_start","Opt-in session")
    self:WatchUsageWindows(true)
    if self.RefreshAdeptCompany then self:RefreshAdeptCompany() end
    SD.Print("Usage recording started. /stonedock record mark <note> adds context; record stop ends it.")
end
function SD:StopUsageRecording(quiet)
    local s=self.usageSession
    if not s or not s.active then if not quiet then SD.Print("Usage recording is stopped.") end return end
    self:RecordUsage("record_stop","Session ended")
    s.active=false
    if eventFrame then eventFrame:UnregisterAllEvents() end
    if self.RefreshAdeptCompany then self:RefreshAdeptCompany() end
    if not quiet then SD.Print("Usage recording stopped. /stonedock record export opens the report.") end
end
function SD:BuildUsageExport(previous)
    local s=previous and StoneDockCharDB.usageRecorderPrevious or StoneDockCharDB.usageRecorder
    if not s then return "No usage session recorded. Use /stonedock record start." end
    local lines={"StoneDock usage recording v1","Addon version: "..tostring(s.addonVersion),
        "Status: "..(s.active and "recording" or "stopped"),
        string.format("Elapsed: %.1f seconds; total events: %d; retained: %d; dropped: %d",s.elapsed,s.total,s.count,s.total-s.count),
        "Privacy: no chat, player names, typed input or combat-log payloads. Explicit manual notes are included (max 140 characters; control characters removed).",
        "Window events show visibility, not intent or proof of a click. Some third-party windows are not instrumented.","","Event counts:"}
    local kinds={}
    for kind in pairs(s.counts) do kinds[#kinds+1]=kind end table.sort(kinds)
    for _,kind in ipairs(kinds) do lines[#lines+1]=kind..": "..s.counts[kind] end
    lines[#lines+1]="" lines[#lines+1]="seconds\tkind\tdetail\tcombat\tlayout\tgroup\tinstance\tui_width\tui_height\tui_scale"
    local first=s.total>LIMIT and s.next or 1
    for i=0,s.count-1 do
        local e=s.events[(first+i-1)%LIMIT+1]
        if e then lines[#lines+1]=string.format("%.1f\t%s\t%s\t%s\t%s\t%s\t%s\t%.1f\t%.1f\t%.4f",e.t,e.kind,e.detail,tostring(e.combat),e.layout,tostring(e.group),e.instance,e.width,e.height,e.scale) end
    end
    local frequency={}
    for i=0,s.count-1 do
        local e=s.events[(first+i-1)%LIMIT+1]
        if e and e.kind=="action" then frequency[e.detail]=(frequency[e.detail] or 0)+1 end
    end
    local actions={}
    for label,count in pairs(frequency) do actions[#actions+1]={label=label,count=count} end
    table.sort(actions,function(a,b)if a.count==b.count then return a.label<b.label end return a.count>b.count end)
    lines[#lines+1]=""
    lines[#lines+1]="Most-used controls (retained events only):"
    for i=1,math.min(10,#actions) do lines[#lines+1]=actions[i].label..": "..actions[i].count end
    return table.concat(lines,"\n")
end
function SD:ShowUsageNote()
    if self:IsBusy() or not self:IsUsageRecording() then return end
    if not self.usageNoteDialog then
        local f=CreateFrame("Frame","StoneDockUsageNote",UIParent,"BackdropTemplate")
        f:SetSize(360,120) f:SetPoint("CENTER") f:SetFrameStrata("DIALOG")
        f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        f:SetBackdropColor(.09,.09,.09,1) f:SetBackdropBorderColor(.83,.73,.49,1)
        local title=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
        title:SetPoint("TOPLEFT",16,-12) title:SetText("Usage recording: add a note")
        local edit=CreateFrame("EditBox",nil,f,"InputBoxTemplate")
        edit:SetSize(324,24) edit:SetPoint("TOPLEFT",18,-36)
        edit:SetMaxLetters(140) edit:SetAutoFocus(false)
        local function save()
            local note=clean(edit:GetText(),140)
            if note:find("%S") and SD:IsUsageRecording() then SD:UsageCommand("mark "..note) end
            f:Hide()
        end
        edit:SetScript("OnEnterPressed",save)
        edit:SetScript("OnEscapePressed",function()f:Hide()end)
        f:SetScript("OnHide",function()edit:ClearFocus()end)
        for i,caption in ipairs({"Save note","Cancel"}) do
            local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
            b:SetSize(100,24) b:SetPoint("BOTTOMRIGHT",-(16+(2-i)*108),12) b:SetText(caption)
            b:SetScript("OnClick",i==1 and save or function()f:Hide()end)
        end
        f.edit=edit self.usageNoteDialog=f
    end
    self.usageNoteDialog:Show() self.usageNoteDialog.edit:SetText("") self.usageNoteDialog.edit:SetFocus()
end
function SD:UsageCommand(argument)
    local command,rest=(argument or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command=(command or ""):lower()
    if command=="start" then self:StartUsageRecording()
    elseif command=="stop" then self:StopUsageRecording()
    elseif command=="mark" then
        if not self:IsUsageRecording() then SD.Print("Start a usage recording before adding a marker.") return end
        self:RecordUsage("marker",rest) SD.Print("Usage marker added.")
    elseif command=="export" then
        if self:IsBusy() then SD.Print("Export usage outside combat and Edit Mode.") return end
        self:ShowCopyDialog("StoneDock usage recording",self:BuildUsageExport(rest=="previous"))
    elseif command=="clear" then
        if self:IsUsageRecording() then SD.Print("Stop recording before clearing it.") return end
        StoneDockCharDB.usageRecorder=nil StoneDockCharDB.usageRecorderPrevious=nil self.usageSession=nil
        SD.Print("Usage recordings cleared.")
    else SD.Print("Usage: record start | stop | mark <note> | export [previous] | clear. Status: "..(self:IsUsageRecording() and "recording" or "stopped")) end
end
SD:On("PLAYER_LOGIN",function()
    local s=StoneDockCharDB.usageRecorder
    if s then s.active=false end
    SD.usageSession=s
end)
