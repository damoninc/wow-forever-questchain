local _, ns = ...

local Widgets = {}
ns.Widgets = Widgets

local colors = {
    accent = { 1, 0.82, 0 },
    text = { 1, 1, 1 },
    muted = { 0.76, 0.73, 0.66 },
    ink = { 0.16, 0.10, 0.05 },
    edge = { 0.41, 0.34, 0.23, 1 },
    card = { 0.10, 0.08, 0.06, 0.90 },
    selected = { 0.32, 0.23, 0.08 },
    connector = { 0.73, 0.58, 0.34, 0.9 },
    optional = { 0.73, 0.58, 0.34, 0.42 },
}
local statuses = {
    completed = { "Completed", 0.47, 0.84, 0.61 },
    ready = { "Ready to turn in", 0.98, 0.81, 0.43 },
    active = { "In progress", 0.46, 0.78, 0.98 },
    blocked = { "Blocked", 0.95, 0.56, 0.48 },
    unstarted = { "Not started", 0.67, 0.69, 0.71 },
}
local itemFallbackIcon = 134400
local panelInset = 36
local cardEdge = { edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

local function fill(parent, layer, r, g, b, a)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetColorTexture(r, g, b, a or 1)
    texture:SetAllPoints()
    return texture
end

local function font(parent, template, color)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetTextColor(unpack(color))
    return text
end

local function label(parent, template, color, x, y, width, value)
    local text = font(parent, template, color)
    text:SetPoint("TOPLEFT", x, -y)
    text:SetWidth(width)
    text:SetText(value)
    return text
end

local function panel(parent, x, top, width, height, heading)
    local frame = CreateFrame("Frame", nil, parent, "ForeverQuestChainListPanelTemplate")
    frame:SetPoint("TOPLEFT", x, -top)
    frame:SetSize(width, height)
    local title, scroll = frame.Heading, frame.ListScroll
    title:SetText(heading)
    scroll.scrollBarHideable = true
    scroll.ScrollBar:Hide()
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local offset = self:GetVerticalScroll() - 48 * delta
        self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
    end)
    local contentWidth = width - panelInset
    local content = scroll:GetScrollChild()
    content:SetWidth(contentWidth)
    return content, scroll, contentWidth, frame, title
end

local function makeButton(parent)
    return CreateFrame("Button", nil, parent, "ForeverQuestChainRowTemplate")
end

local function makeLocationButton(parent)
    local button = CreateFrame("Button", nil, parent, "ForeverQuestChainLocationCardTemplate")
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.category.name)
        GameTooltip:AddLine(self.level:GetText(), 1, 0.82, 0)
        GameTooltip:AddLine(self.counts, 1, 1, 1)
        GameTooltip:AddLine("Click to view quests and rewards.", 0.76, 0.73, 0.66)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    button:SetScript("OnHide", button:GetScript("OnLeave"))
    return button
end

local function makeControl(parent, title, width)
    local button = CreateFrame("Button", nil, parent, "ForeverQuestChainControlTemplate")
    button:SetWidth(width)
    button:SetText(title)
    return button
end

local function makeBreadcrumb(parent, current)
    local button = CreateFrame("Button", nil, parent, "ForeverQuestChainBreadcrumbTemplate")
    Widgets.bindBreadcrumb(button, current)
    return button
end

function Widgets.bindBreadcrumb(button, current)
    local color = current and colors.text or colors.accent
    local text = button.crumbText
    text:SetTextColor(unpack(color))
    button:SetScript("OnEnter", function() text:SetTextColor(unpack(current and colors.accent or colors.text)) end)
    local function resetColor() text:SetTextColor(unpack(color)) end
    button:SetScript("OnLeave", resetColor)
    button:SetScript("OnHide", resetColor)
end

local function setBreadcrumbText(button, title, maxWidth)
    local text = button.crumbText
    text:SetText(title)
    local width = math.max(1, math.min(290, maxWidth or 290, math.ceil(text:GetUnboundedStringWidth())))
    text:SetWidth(width)
    button:SetWidth(width)
end

local function makeBrowseMenu(parent, x, top, width)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", x, -top)
    dropdown:SetWidth(width)
    dropdown.Text:SetJustifyH("LEFT")
    return dropdown
end

local function setupCategoryMenu(dropdown, options, prompt, selected, choose)
    if prompt then dropdown:SetDefaultText(prompt) end
    dropdown:SetEnabled(#options > 0)
    dropdown:SetupMenu(function(_, menu)
        menu:SetScrollMode(280)
        for _, option in ipairs(options) do
            local key = option.key
            menu:CreateRadio(option.name, function() return selected() == key end, function() choose(key) end)
        end
    end)
end

local partyTextColor = { 0.55, 0.82, 1 }
local partyLineHeight = 15

local function hideOwnedTooltip(row)
    if GameTooltip and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

local function addPartyStatus(row, x, y, width)
    row.partyStatus = row.partyStatus or label(row, "GameFontHighlightSmall", partyTextColor, x, y, width, "")
    row:SetScript("OnEnter", function(self)
        if not self.partyNames then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Party members on this quest")
        for _, name in ipairs(self.partyNames) do GameTooltip:AddLine(name, 1, 1, 1) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", hideOwnedTooltip)
    row:SetScript("OnHide", hideOwnedTooltip)
end

local function setPartyStatus(row, members)
    row.partyNames = members
    row.partyStatus:SetText(members and ("Party: %d"):format(#members) or "")
end

local function makeTimelineButton(parent)
    local button = CreateFrame("Button", nil, parent, "ForeverQuestChainTimelineCardTemplate")
    button:SetBackdrop(cardEdge)
    button.title:SetWordWrap(true)
    button.title:SetMaxLines(2)
    button.meta:ClearAllPoints()
    button.meta:SetPoint("TOPLEFT", 8, -35)
    addPartyStatus(button)
    return button
end

local function hideAll(list)
    for _, region in ipairs(list) do
        region:Hide()
    end
end

local function updateScroll(scroll, offset)
    scroll:UpdateScrollChildRect()
    scroll:SetVerticalScroll(math.max(0, math.min(offset, scroll:GetVerticalScrollRange())))
end

local function resetScroll(scroll, content, height, offset)
    content:SetHeight(math.max(1, height))
    updateScroll(scroll, offset)
end

local function itemName(item)
    return item.name or C_Item.GetItemNameByID(item.id) or ("Item #" .. item.id)
end

local function showTooltip(button)
    local item = button.reward
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if item.link then
        GameTooltip:SetHyperlink(item.link)
    else
        GameTooltip:SetItemByID(item.id)
    end
    GameTooltip:Show()
end

local function tryLinkReward(button)
    if not IsModifiedClick("CHATLINK") then return false end
    local item = button.reward
    local link = item.link or select(2, C_Item.GetItemInfo(item.id))
    return link and ChatFrameUtil.InsertLink(link)
end

Widgets.colors = colors
Widgets.statuses = statuses
Widgets.itemFallbackIcon = itemFallbackIcon
Widgets.panelInset = panelInset
Widgets.partyLineHeight = partyLineHeight
Widgets.fill = fill
Widgets.font = font
Widgets.label = label
Widgets.panel = panel
Widgets.makeButton = makeButton
Widgets.makeLocationButton = makeLocationButton
Widgets.makeControl = makeControl
Widgets.makeBreadcrumb = makeBreadcrumb
Widgets.setBreadcrumbText = setBreadcrumbText
Widgets.makeBrowseMenu = makeBrowseMenu
Widgets.setupCategoryMenu = setupCategoryMenu
Widgets.addPartyStatus = addPartyStatus
Widgets.setPartyStatus = setPartyStatus
Widgets.makeTimelineButton = makeTimelineButton
Widgets.hideAll = hideAll
Widgets.updateScroll = updateScroll
Widgets.resetScroll = resetScroll
Widgets.itemName = itemName
Widgets.showTooltip = showTooltip
Widgets.tryLinkReward = tryLinkReward
Widgets.hideOwnedTooltip = hideOwnedTooltip
