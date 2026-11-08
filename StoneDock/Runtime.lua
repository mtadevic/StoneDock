local _, SD = ...

function SD:CardAccent()
    if self.db and self.db.stoneTexture=="kintsugi" then return .86,.67,.40 end
    return .49,.86,.66
end

-- Shared expedition-style surfaces for settings, tools and status cards.
function SD:StyleCard(frame, active)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    if self.db and self.db.stoneTexture=="kintsugi" then
        frame:SetBackdropColor(.018,.017,.016,.98)
        frame:SetBackdropBorderColor(active and .73 or .40,active and .53 or .30,active and .27 or .18,1)
    else
        frame:SetBackdropColor(.025,.065,.058,.97)
        frame:SetBackdropBorderColor(active and .30 or .17,active and .68 or .34,active and .48 or .28,1)
    end
end
function SD:StyleAction(button)
    self:StyleCard(button,false)
    if button.SetNormalTexture then button:SetNormalTexture("") end
    if button.SetPushedTexture then button:SetPushedTexture("") end
    if button.SetHighlightTexture then button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD") end
    if button.GetFontString then local label=button:GetFontString() if label then label:SetTextColor(self:CardAccent()) end end
end

-- Reuse dynamic window controls. WoW frames are not garbage-collected when
-- hidden, so rebuilding a menu must not allocate another full frame tree.
function SD:WindowBuilder(key)
    self.windowPools=self.windowPools or {}
    local pool=self.windowPools[key]
    if not pool then pool={frames={},texts={}}self.windowPools[key]=pool end
    for _,buckets in pairs(pool.frames)do for _,list in pairs(buckets)do for _,frame in ipairs(list)do frame:Hide()end end end
    for _,list in pairs(pool.texts)do for _,label in ipairs(list)do label:Hide()end end
    local usedFrames,usedTexts={},{}
    local function frame(kind,name,parent,template)
        parent=parent or UIParent
        local kindKey=kind..":"..(template or "")
        pool.frames[parent]=pool.frames[parent] or {}
        local list=pool.frames[parent][kindKey] or {} pool.frames[parent][kindKey]=list
        usedFrames[parent]=usedFrames[parent] or {}
        local n=(usedFrames[parent][kindKey] or 0)+1 usedFrames[parent][kindKey]=n
        if not list[n]then list[n]=CreateFrame(kind,name,parent,template)end
        local result=list[n] result:ClearAllPoints()result:Show()
        return result
    end
    local H={}
    function H.text(parent,caption,size,x,y,width)
        local list=pool.texts[parent]or {}pool.texts[parent]=list
        local n=(usedTexts[parent]or 0)+1 usedTexts[parent]=n
        if not list[n]then list[n]=parent:CreateFontString(nil,"OVERLAY")end
        local label=list[n]label:ClearAllPoints()label:SetFont("Fonts\\FRIZQT__.TTF",size,"")label:SetPoint("TOPLEFT",x,y)
        label:SetTextColor(.73,.79,.83)label:SetWidth(width or 275)label:SetJustifyH("LEFT")label:SetText(caption)label:Show()
        return label
    end
    function H.card(parent,title,detail,x,y,width,height,active)
        local card=frame("Frame",nil,parent,"BackdropTemplate")
        card:SetPoint("TOPLEFT",x,y) card:SetSize(width,height) SD:StyleCard(card,active)
        if title then card.title=H.text(card,title,16,16,-13,width-32) card.title:SetTextColor(SD:CardAccent()) end
        if detail then card.detail=H.text(card,detail,12,16,-40,width-32) end
        return card
    end
    function H.button(parent,caption,x,y,width,fn)
        local b=frame("Button",nil,parent,"UIPanelButtonTemplate,BackdropTemplate")b:SetPoint("TOPLEFT",x,y)b:SetSize(width,30)b:SetText(caption) SD:StyleAction(b)
        b:SetScript("OnClick",function()SD:Run(caption,fn)end)
        return b
    end
    return frame,H
end

-- Bound asynchronous item-data requests. Ignore completions that StoneDock
-- never requested; an unavailable item cannot produce a request/rescan loop.
function SD:RequestItemData(id)
    if not C_Item or not C_Item.RequestLoadItemDataByID then return end
    self.itemDataRequests=self.itemDataRequests or {}
    if self.itemDataRequests[id]then return end
    self.itemDataRequests[id]="pending"
    C_Item.RequestLoadItemDataByID(id)
end
SD:On("GET_ITEM_INFO_RECEIVED",function(id,success)
    if not SD.itemDataRequests or SD.itemDataRequests[id]~="pending"then return end
    SD.itemDataRequests[id]=success==false and "failed" or "loaded"
    if success~=false then SD:QueueConsumables()end
end)

-- Native layout records are plain data. Equality avoids writes and their
-- follow-up event cascades when applying an already-matching configuration.
function SD.Equal(a,b,seen)
    if a==b then return true end
    if type(a)~="table" or type(b)~="table"then return false end
    seen=seen or {}if seen[a]==b then return true end seen[a]=b
    for key,value in pairs(a)do if not SD.Equal(value,b[key],seen)then return false end end
    for key in pairs(b)do if a[key]==nil then return false end end
    return true
end

SD:On("BAG_UPDATE_DELAYED",function()
    -- A real inventory change may make a previously unavailable item resolvable.
    -- Completion events themselves never reset this bound.
    for id,state in pairs(SD.itemDataRequests or {})do if state~="pending"then SD.itemDataRequests[id]=nil end end
end)
