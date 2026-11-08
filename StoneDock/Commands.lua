local _, SD = ...

function SD:BuildReport()
    local version, build, _, interface = GetBuildInfo()
    local g = self:GetGeometry()
    local physicalW, physicalH
    if GetPhysicalScreenSize then physicalW, physicalH = GetPhysicalScreenSize() end
    local lines = {
        "StoneDock " .. self.version .. " diagnostic report",
        "Client: " .. tostring(version) .. " / " .. tostring(build) .. " / interface " .. tostring(interface),
        "Physical display: " .. tostring(physicalW) .. " x " .. tostring(physicalH),
        string.format("UI canvas: %.1f x %.1f; scale %.4f; design scale %.4f", UIParent:GetWidth(), UIParent:GetHeight(), UIParent:GetEffectiveScale(), g.scale),
        "Density: " .. tostring(self.db.density) .. "; panels enabled: " .. tostring(self.db.enabled),
        "Combat: " .. tostring(InCombatLockdown()),
        "Current-session error: " .. tostring(self.lastError or "none"),
        "Previous recorded error: " .. tostring(StoneDockCharDB.lastError or "none"),
        "", "Item bar:",
    }
    lines[#lines+1]="Blocked interface actions (most recent 8):"
    for _,record in ipairs(StoneDockCharDB.blockedActions or {}) do
        lines[#lines+1]=string.format("%s | %s | %s | %s | combat=%s | count=%d | %s",record.time,record.event,record.addon,record.action,tostring(record.combat),record.count,record.context)
        if record.stack then lines[#lines+1]=record.stack end
    end
    if not StoneDockCharDB.blockedActions or #StoneDockCharDB.blockedActions==0 then lines[#lines+1]="None captured. Events before this update cannot be recovered." end
    lines[#lines+1]=""
    local _,primary=self:GetConsumableSpec()
    lines[#lines+1]="Primary stat: "..primary
    lines[#lines+1]="Bag scan: "..(self.itemsDirty and "pending" or self.consumableLists and "ready" or "unavailable")
    for _,category in ipairs(self.itemCategories) do
        local choices=self:GetUtilityChoices(category.key)
        local selected,pinned=self:GetChosenItem(category.key)
        local shown=false
        for _,button in ipairs(self.utilityButtons or {}) do
            if button.category==category then
                shown=button:IsShown()
                break
            end
        end
        local selection=selected and (selected.name.." ["..selected.id.."]") or "none"
        lines[#lines+1]=string.format("%s: %d choices, %s%s, button %s",category.label,
            #choices,selection,pinned and " (pinned)" or "",shown and "shown" or "hidden")
    end
    lines[#lines+1]=""
    lines[#lines+1]="Native frame geometry:"
    for _, name in ipairs({ "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MinimapCluster", "PlayerFrame", "TargetFrame", "ChatFrame1", "MicroMenu", "BagsBar", "CompactPartyFrame", "CompactRaidFrameContainer" }) do
        local f = _G[name]
        if f then
            local point, relative, relativePoint, x, y = f:GetPoint(1)
            local relativeName = relative and relative.GetName and relative:GetName() or "nil"
            table.insert(lines, string.format("%s: %.1fx%.1f scale=%.3f shown=%s; %s %s %s %.1f %.1f", name, f:GetWidth(), f:GetHeight(), f:GetScale(), tostring(f:IsShown()), tostring(point), tostring(relativeName), tostring(relativePoint), x or 0, y or 0))
        else table.insert(lines, name .. ": absent") end
    end
    local full, err = self:GetFullLayouts()
    table.insert(lines, "")
    if full then
        table.insert(lines, "Active layout index: " .. tostring(full.activeLayout))
        local active=full.layouts[full.activeLayout]
        for _,info in ipairs(active and active.systems or {}) do
            if info.system==Enum.EditModeSystem.ActionBar and info.systemIndex<=3 then
                for _,setting in ipairs(info.settings or {}) do
                    if setting.setting==Enum.EditModeActionBarSetting.NumIcons then
                        lines[#lines+1]="Native bar "..info.systemIndex.." saved button count: "..tostring(setting.value)
                    end
                end
            end
        end
        for index, layout in ipairs(full.layouts) do
            table.insert(lines, string.format("Layout %d: %s; type=%s; systems=%d", index, tostring(layout.layoutName), tostring(layout.layoutType), #(layout.systems or {})))
        end
    else table.insert(lines, "Edit Mode unavailable: " .. tostring(err)) end
    return table.concat(lines, "\n")
end

function SD:ShowReport()
    local report = self:BuildReport()
    StoneDockCharDB.lastReport = report
    self:ShowCopyDialog("StoneDock diagnostics", report)
end

function SD:Command(message)
    local command, arg = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    if command == "" or command == "options" then self:ToggleOptions()
    elseif command=="modules"then self:OpenSettingsTab("master")
    elseif command=="session"or command=="readiness"or command=="waypoints"or command=="quests"then self:OpenSettingsTab(command)
    elseif command=="notes"then self:OpenSettingsTab("notesCustomize")
    elseif command == "profiles" or command=="backups" then self:ShowProfiles()
    elseif command == "move" then self:ShowPositioning()
    elseif command == "snapshot" then self:SaveSnapshot(arg)
    elseif command == "loadsnapshot" then self:RestoreSnapshot(arg)
    elseif command == "hearth" then self:ShowHearthMenu()
    elseif command == "close" then
        self:CloseSettings()
        for _,key in ipairs({"options","advanced","unitOptions","profileWindow","positionWindow","itemPicker","rivetMenu"}) do if self[key] then self[key]:Hide() end end
        if self.itemFlyout and not InCombatLockdown() then self.itemFlyout:Hide() end
        if self.hearthMenu and not InCombatLockdown() then self.hearthMenu:Hide() end
    elseif command == "itemauto" then
        local spec=self:GetConsumableSpec()
        if self.db.itemOverrides[spec] then self.db.itemOverrides[spec][arg]=nil end
        self:RefreshUtilityButtons(true)
    elseif command == "rivets" then self:ShowRivetAssignments("left1",self.rivetControls.left1)
    elseif command == "items" then
        local key=arg~="" and arg:lower() or "bufffood"
        if key=="refresh" then
            if InCombatLockdown() then
                self:QueueConsumables()
                SD.Print("Item bar refresh queued for after combat.")
            else
                self:RefreshUtilityButtons(true)
                SD.Print("Item bar refreshed.")
            end
            return
        end
        if key=="hearth" then self:ShowItemPicker("hearth","Hearthstones") return end
        for _,category in ipairs(self.itemCategories) do
            if category.key==key then self:ShowItemPicker(key,category.label) return end
        end
        SD.Print("Item categories: bandage, heal, resource, bufffood, buffpotion, alternate, food, drink, utility, hearth. Use /stonedock items refresh to rescan.")
    elseif command == "auras" then self:ApplySessionLayout(true)
    elseif command == "units" then self:ToggleUnitOptions()
    elseif command == "raidpreview" then self:PreviewRaid(tonumber(arg) or 20)
    elseif command == "advanced" or command == "position" or command == "fade" then self:ToggleAdvanced(true)
    elseif command == "install" or command == "activate" then self:ActivateLayout()
    elseif command == "restore" then self:RestoreLayout()
    elseif command == "rebuild" then self:ConfirmRebuild()
    elseif command == "align" then self:AlignLayout()
    elseif command == "edit" then self:OpenEditMode()
    elseif command == "report" then self:ShowReport()
    elseif command == "export" then self:ExportLayout()
    elseif command == "hud" then
        self.db.showHUD = not self.db.showHUD
        self:RefreshHUD()
    elseif command == "hudscale" and tonumber(arg) then
        self.db.hudScale = SD.Clamp(tonumber(arg), 0.6, 1.4)
        self:RefreshHUD()
    elseif command == "preview" then
        self.db.showGuides = not self.db.showGuides
        self:RefreshPanels()
    elseif command == "show" or command == "hide" then
        self.db.enabled = command == "show"
        self:RefreshPanels()
    elseif command == "accent" and self.colors[arg] then
        self.db.accent = arg self:RefreshPanels()
    elseif command == "opacity" and tonumber(arg) then
        self.db.opacity = SD.Clamp(tonumber(arg), 0.4, 1) self:RefreshPanels()
    elseif command == "height" and tonumber(arg) then
        self.db.density = SD.Clamp(tonumber(arg), 0.8, 1.2) self:RefreshPanels()
        SD.Print("Panel height changed. Use /stonedock rebuild to match native frame placement.")
    else
        SD.Print("/stonedock opens settings. Commands: install, restore, rebuild, edit, preview, show, hide, report, export.")
        SD.Print("Appearance: accent silver|violet|green|bronze; opacity 0.4-1; height 0.8-1.2; hud; hudscale 0.6-1.4.")
    end
end

SLASH_STONEDOCK1 = "/stonedock"
SLASH_STONEDOCK2 = "/sdock"
SlashCmdList.STONEDOCK = function(message) SD:Run("Command", function() SD:Command(message) end) end
