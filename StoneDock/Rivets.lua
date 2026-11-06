local _, SD = ...
local actions={
    {"options","Open appearance settings"},{"units","Open unit / raid settings"},
    {"advanced","Open position / fading settings"},{"hud","Toggle curved health HUD"},
    {"fade","Toggle out-of-combat dashboard fading"},{"info","Toggle Field Notes information"},
    {"utility","Toggle trinket / consumable row"},{"preview","Toggle party preview"},
    {"labels","Toggle stone panel captions"},{"gathering","Open gathering settings"},{"none","No action"},
}
local names={left="Conversation",right="Field Notes",map="Map",leftWell="Left action bars",rightWell="Right action bars"}
local defaults={left={"options","fade"},right={"utility","info"},map={"units","hud"},leftWell={"advanced","preview"},rightWell={"advanced","preview"}}
local function caption(id)
    for _,entry in ipairs(actions) do if entry[1]==id then return entry[2] end end
    return "No action"
end
function SD:DoRivetAction(action)
    if action=="options" then self:ToggleOptions(true)
    elseif action=="units" then self:ToggleUnitOptions()
    elseif action=="advanced" then self:ToggleAdvanced(true)
    elseif action=="hud" then self.db.showHUD=not self.db.showHUD self:RefreshHUD()
    elseif action=="fade" then self.db.fadeUI=not self.db.fadeUI self:RefreshFading()
    elseif action=="info" then self.db.showInfo=not self.db.showInfo self:RefreshPanels()
    elseif action=="utility" then
        if InCombatLockdown() then SD.Print("Toggle the item row after combat.") return end
        self.db.showUtility=not self.db.showUtility self:RefreshUtilityButtons()
    elseif action=="preview" then self:PreviewRaid(self.raidPreview and 0 or 5)
    elseif action=="gathering" then self:OpenSettingsTab("gathering")
    elseif action=="labels" then self.db.showLabels=not self.db.showLabels self:RefreshPanels() end
end
function SD:ShowRivetAssignments(key,anchor)
    if self.rivetMenu then self.rivetMenu:Hide() end
    local CreateFrame,H=self:WindowBuilder("rivetMenu")
    local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate") self.rivetMenu=f
    f:SetSize(345,430) f:SetPoint("BOTTOMRIGHT",anchor,"TOPRIGHT",0,8) f:SetClampedToScreen(true) f:SetFrameStrata("DIALOG")
    f:SetBackdrop({bgFile="Interface\\AddOns\\StoneDock\\Media\\Stone.tga",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=256,edgeSize=14})
    H.text(f,"ASSIGN RIVET",16,18,-18,310)
    for i,entry in ipairs(actions) do
        H.button(f,entry[2],14,-45-(i-1)*30,317,function() SD.db.rivetActions[key]=entry[1] SD:OpenSettingsTab("rivets",key,anchor) end)
    end
    H.button(f,"Close settings",14,-385,317,function() SD:CloseSettings() end)
    f:Show()
end
function SD:CreateRivetControls()
    if self.rivetControls or not self.panels then return end
    self.rivetControls={}
    for panelName,title in pairs(names) do
        local panel=self.panels[panelName]
        for i,point in ipairs({"TOPLEFT","TOPRIGHT"}) do
            local key=panelName..i
            local b=CreateFrame("Button",nil,panel)
            b:SetSize(19,19) b:SetPoint(point,panel,point,i==1 and 1 or -1,-1)
            b:SetFrameStrata("HIGH") b:SetFrameLevel(25) b:RegisterForClicks("LeftButtonUp","RightButtonUp")
            local hover=b:CreateTexture(nil,"HIGHLIGHT") hover:SetAllPoints() hover:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight") hover:SetBlendMode("ADD")
            b:SetScript("OnClick",function(_,mouse)
                if mouse=="RightButton" then SD:ShowRivetAssignments(key,b)
                else SD:Run("Rivet",function() SD:DoRivetAction(SD.db.rivetActions[key] or defaults[panelName][i]) end) end
            end)
            b:SetScript("OnEnter",function()
                GameTooltip:SetOwner(b,"ANCHOR_TOP")
                GameTooltip:AddLine(title.." rivet")
                GameTooltip:AddLine(caption(SD.db.rivetActions[key] or defaults[panelName][i]),.75,.85,.9)
                GameTooltip:AddLine("Right-click to assign an action",.55,.65,.75)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave",function() GameTooltip:Hide() end)
            self.rivetControls[key]=b
        end
    end
end
SD:On("PLAYER_LOGIN",function() SD:CreateRivetControls() end)

