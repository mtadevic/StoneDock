local _, SD = ...

function SD:UpdateExpeditionCard(bagText)
    local details = self:GetExpeditionDetails()
    local parent = self.panels and self.panels.right
    if not parent then return end
    local card = self.expeditionCard
    if not card then
        card = CreateFrame("Frame",nil,parent,"BackdropTemplate")
        self.expeditionCard = card
        card:SetFrameLevel(parent:GetFrameLevel()+6)
        card:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        card:SetBackdropColor(.025,.07,.06,.94)
        card:SetBackdropBorderColor(.24,.56,.41,1)
        local function text(size)
            local label=card:CreateFontString(nil,"OVERLAY")
            label:SetFont("Fonts\\FRIZQT__.TTF",size,"")
            label:SetJustifyH("LEFT")
            return label
        end
        card.icon=card:CreateTexture(nil,"ARTWORK")
        card.icon:SetPoint("TOPLEFT",9,-9)
        card.icon:SetSize(25,25)
        card.title=text(12)
        card.title:SetPoint("TOPLEFT",43,-8)
        card.title:SetPoint("TOPRIGHT",-10,-8)
        card.title:SetWordWrap(false)
        card.detail=text(10)
        card.detail:SetPoint("TOPLEFT",43,-24)
        card.detail:SetPoint("TOPRIGHT",-10,-24)
        card.detail:SetWordWrap(false)
        card.count=text(10)
        card.count:SetPoint("TOPLEFT",10,-33)
        card.count:SetPoint("TOPRIGHT",-10,-33)
        card.count:SetWordWrap(false)
        card.track=card:CreateTexture(nil,"BACKGROUND")
        card.track:SetPoint("BOTTOMLEFT",10,26)
        card.track:SetPoint("BOTTOMRIGHT",-10,26)
        card.track:SetHeight(3)
        card.track:SetColorTexture(.1,.2,.16,1)
        card.progress=card:CreateTexture(nil,"ARTWORK")
        card.progress:SetPoint("BOTTOMLEFT",10,26)
        card.progress:SetHeight(3)
        card.progress:SetColorTexture(.35,.82,.57,1)
        local function control(caption,x,width,action)
            local button=CreateFrame("Button",nil,card,"UIPanelButtonTemplate")
            button:SetPoint("BOTTOMLEFT",x,4)
            button:SetSize(width,19)
            button:SetText(caption)
            button:SetScript("OnClick",function()
                if SD:IsBusy() then SD.Print("Use expedition controls outside combat and Edit Mode.") return end
                SD:Run("Expedition action",action)
            end)
            return button
        end
        card.skip=control("Next stop",8,92,function()
            if SD.oreRoute then SD:AdvanceOreRoute()
            elseif SD.gathering and SD.gathering.targetID then SD:StartOreRoute(SD.gathering.targetID) end
        end)
        card.configure=control("Expedition",106,92,function()SD:OpenSettingsTab("gathering")end)
        card.stop=control("End",204,70,function()
            SD.fishingAutoPaused=true
            SD:StopGathering()
        end)
    end
    local visible=self.db.showInfo
    card:SetShown(visible)
    if not visible then return end
    local g=self.geometry or self:GetGeometry()
    local height=math.max(65,math.min(100,g.right.h-106-g.utilityY-20.4-8))
    self:StyleCard(card,details.active)
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT",parent,"TOPLEFT",12,-106)
    card:SetSize(g.right.w-24,height)
    local state=self.gathering or {}
    local fishing=state.mode=="fishing"
    local icon=state.targetID and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(state.targetID)
    card.icon:SetTexture(icon or (fishing and "Interface\\Icons\\Trade_Fishing" or "Interface\\Icons\\Trade_Mining"))
    card.title:SetText(details.title)
    card.title:SetTextColor(self:CardAccent())
    card.detail:SetText(details.paused or (self.oreRoute and details.detail) or details.destination or (details.active and details.detail or "Choose Expedition to plan your next trip."))
    card.count:SetText(details.active and (details.count.."  |  "..(bagText or "")) or (bagText or ""))
    card.track:SetShown(details.active and height>=76)
    card.progress:SetShown(details.active and height>=76)
    card.progress:SetColorTexture(self:CardAccent())
    card.progress:SetWidth(math.max(1,(g.right.w-44)*(details.progress or 0)))
    for _,button in ipairs({card.skip,card.configure,card.stop}) do button:EnableMouse(not self.editing) end
    card.stop:SetShown(details.active)
    card.skip:SetShown(details.active and (self.oreRoute~=nil or state.targetID~=nil))
    if parent.caption then parent.caption:SetText("COMMAND CENTER") end
end
