local _, SD = ...
SD.noteRowDefinitions={{"zone","Location"},{"bags","Bag space"},{"durability","Durability"},{"money","Gold"},{"clock","Clock"},{"performance","FPS / latency"},{"profile","Spec / profile"}}
SD.noteActionDefinitions={{"default","Default action"},{"none","No click action"},{"map","World map"},{"bags","Inventory"},{"equipment","Equipment"},{"currency","Currencies"},{"calendar","Calendar"},{"diagnostics","Diagnostics"},{"profiles","Profiles & backups"},{"session","Session tracker"},{"readiness","Readiness checklist"},{"waypoints","Waypoint desk"},{"quests","Quest notebook"},{"settings","Master Modules"}}
function SD:IsNoteRowEnabled(key)
    return not self:IsModuleEnabled("notesCustomize")or self.db.noteRows[key]~=false
end
function SD:NoteActionLabel(key)
    local action=self:IsModuleEnabled("notesCustomize")and self.db.noteActions[key]or "default"
    for _,entry in ipairs(self.noteActionDefinitions)do if entry[1]==action then return entry[2]end end
    return "Default action"
end
function SD:DispatchNoteAction(key,fallback)
    local action=self:IsModuleEnabled("notesCustomize")and self.db.noteActions[key]or "default"
    if not action or action=="default"then return fallback()end
    if action=="none"then return end
    if action=="map"and ToggleWorldMap then ToggleWorldMap()
    elseif action=="bags"and ToggleAllBags then ToggleAllBags()
    elseif action=="equipment"and ToggleCharacter then ToggleCharacter("PaperDollFrame")
    elseif action=="currency"and ToggleCharacter then ToggleCharacter("TokenFrame")
    elseif action=="calendar"and ToggleCalendar then ToggleCalendar()
    elseif action=="diagnostics"then self:ShowReport()
    elseif action=="profiles"then self:ShowProfiles()
    elseif action=="settings"then self:OpenSettingsTab("master")
    elseif action=="session"or action=="readiness"or action=="waypoints"or action=="quests"then self:OpenSettingsTab(action)end
end
function SD:BuildNotesPanel()
    local CreateFrame,H=self:WindowBuilder("notesCustomizePanel")
    local f=CreateFrame("Frame",nil,UIParent)self.notesCustomizePanel=f f:SetSize(690,700)
    H.text(f,"CUSTOMIZE FIELD NOTES",22,22,-22,640)
    H.text(f,"Choose which rows appear above the item drawers. Click an action button to cycle its shortcut. Right-click any Field Notes row to return here. Hidden rows compact automatically.",12,22,-62,640)
    f.checks={}f.actions={}
    for i,entry in ipairs(self.noteRowDefinitions)do
        local key,title=entry[1],entry[2]local y=-130-(i-1)*60
        local b=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")b:SetSize(25,25)b:SetPoint("TOPLEFT",22,y)b:SetChecked(self.db.noteRows[key]~=false)
        H.text(b,title,13,30,-5,250)
        b:SetScript("OnClick",function(button)self.db.noteRows[key]=button:GetChecked()==true self.noteLayoutKey=nil self:UpdateInfo()end)
        local action=H.button(f,self:NoteActionLabel(key),310,y,335,function()
            local current=SD.db.noteActions[key]or "default"local n=1
            for index,option in ipairs(SD.noteActionDefinitions)do if option[1]==current then n=index break end end
            SD.db.noteActions[key]=SD.noteActionDefinitions[n%#SD.noteActionDefinitions+1][1]
            SD:OpenSettingsTab("notesCustomize")
        end)
        f.checks[key]=b f.actions[key]=action
    end
    H.button(f,"Restore Field Notes defaults",22,-590,620,function()SD.db.noteRows={}SD.db.noteActions={}SD.noteLayoutKey=nil SD:UpdateInfo()SD:OpenSettingsTab("notesCustomize")end)
    return f
end
