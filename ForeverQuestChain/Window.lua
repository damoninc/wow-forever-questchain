local _, ns = ...

local Window = {}
ns.Window = Window

local colors = {
    accent = { 1, 0.82, 0 },
    text = { 1, 1, 1 },
    muted = { 0.76, 0.73, 0.66 },
    ink = { 0.16, 0.10, 0.05 },
    inkHeading = { 0.31, 0.17, 0.07 },
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
local cardEdge = { edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }
local questHighlight = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

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

local function panel(parent, x, top, width, height, heading, parchment)
    local frame = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    frame:SetPoint("TOPLEFT", x, -top)
    frame:SetSize(width, height)
    if parchment then
        local paper = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
        paper:SetAtlas("QuestDetailsBackgrounds")
        paper:SetPoint("TOPLEFT", 3, -3)
        paper:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    local title = label(frame, parchment and "QuestFont" or "GameFontNormalSmall",
        parchment and colors.inkHeading or colors.accent, 12, 12, width - 24, heading)
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -36)
    scroll:SetPoint("BOTTOMRIGHT", -26, 10)
    scroll.scrollBarHideable = true
    scroll.ScrollBar:Hide()
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local offset = self:GetVerticalScroll() - 48 * delta
        self:SetVerticalScroll(math.max(0, math.min(offset, self:GetVerticalScrollRange())))
    end)
    local content = CreateFrame("Frame", nil, scroll)
    local contentWidth = width - 36
    content:SetSize(contentWidth, 1)
    scroll:SetScrollChild(content)
    return content, scroll, contentWidth, frame, title
end

local function makeButton(parent, template)
    local button = CreateFrame("Button", nil, parent, template)
    button.background = fill(button, "BACKGROUND", unpack(colors.card))
    button:SetHighlightTexture(questHighlight, "ADD")
    button.title = font(button, "GameFontHighlight", colors.text)
    button.title:SetPoint("TOPLEFT", 8, -6)
    button.title:SetWordWrap(false)
    button.meta = font(button, "GameFontHighlightSmall", colors.muted)
    button.meta:SetPoint("TOPLEFT", 8, -24)
    button.meta:SetWordWrap(false)
    return button
end

local function makeControl(parent, title, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetText(title)
    return button
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

local function makeTimelineButton(parent)
    local button = makeButton(parent, "BackdropTemplate")
    button:SetBackdrop(cardEdge)
    button.title:SetWordWrap(true)
    button.title:SetMaxLines(2)
    button.meta:ClearAllPoints()
    button.meta:SetPoint("TOPLEFT", 8, -35)
    button.note = label(button, "GameFontHighlightSmall", colors.muted, 8, 49, 1, "")
    button.note:SetWordWrap(false)
    button.statusMark = button:CreateTexture(nil, "ARTWORK")
    button.statusMark:SetPoint("TOPLEFT")
    button.statusMark:SetPoint("BOTTOMLEFT")
    button.statusMark:SetWidth(3)
    return button
end

local function hideAll(list)
    for _, region in ipairs(list) do
        region:Hide()
    end
end

local function resetScroll(scroll, content, height, offset)
    content:SetHeight(math.max(1, height))
    scroll:UpdateScrollChildRect()
    scroll:SetVerticalScroll(math.max(0, math.min(offset, scroll:GetVerticalScrollRange())))
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

local function createRewardPage(parent, top, height, callbacks)
    local config = callbacks.rewardPage
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", 14, -top)
    frame:SetSize(972, height)
    local kind = makeBrowseMenu(frame, 12, 28, 168)
    setupCategoryMenu(kind, config.kinds, nil, config.kind, config.selectKind)
    local category = makeBrowseMenu(frame, 200, 28, 312)
    label(frame, "GameFontNormalSmall", colors.muted, 12, 10, 180, "BROWSE BY")
    label(frame, "GameFontNormalSmall", colors.muted, 200, 10, 312, "LOCATION")
    label(frame, "GameFontNormalSmall", colors.muted, 532, 10, 260, "FIND AN ITEM")
    local query = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    query:SetPoint("TOPLEFT", 536, -28)
    query:SetSize(290, 24)
    query:SetAutoFocus(false)
    query:SetMaxLetters(100)
    local hint = label(frame, "GameFontDisableSmall", colors.muted, 540, 34, 272, "Item name or ID")
    query:SetScript("OnTextChanged", function(self)
        local value = self:GetText()
        hint:SetShown(value == "")
        config.search(value)
    end)
    query:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    query:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local list, listScroll, listWidth, _, listTitle = panel(frame, 0, 63, 620, height - 63, "QUEST REWARDS")
    local sources, sourceScroll, sourceWidth = panel(frame, 630, 63, 342, height - 63, "REWARD SOURCES")
    local listMessage = label(list, "GameFontHighlightSmall", colors.muted, 2, 4, listWidth - 4, "")
    local sourceTitle = label(sources, "GameFontNormalLarge", colors.accent, 2, 4, sourceWidth - 4, "")
    local sourceMeta = font(sources, "GameFontHighlightSmall", colors.muted)
    sourceMeta:SetWidth(sourceWidth - 4)
    local itemRows, sourceRows = {}, {}
    local selectedId

    local function showItems(entries, selection, message, offset)
        hideAll(itemRows)
        hideAll(sourceRows)
        listTitle:SetText(selection and ("QUEST REWARDS  /  " .. #entries) or "QUEST REWARDS")
        listMessage:SetText(message or "")
        listMessage:SetShown(message ~= nil)
        for index, entry in ipairs(entries) do
            local item = entry.item
            local row = itemRows[index]
            if not row then
                row = makeButton(list)
                row:SetSize(listWidth, 38)
                row.title:ClearAllPoints()
                row.title:SetPoint("TOPLEFT", 42, -6)
                row.title:SetWidth(listWidth - 50)
                row.meta:ClearAllPoints()
                row.meta:SetPoint("TOPLEFT", 42, -22)
                row.meta:SetWidth(listWidth - 50)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetPoint("LEFT", 5, 0)
                row.icon:SetSize(28, 28)
                row:SetScript("OnEnter", showTooltip)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                row:SetScript("OnHide", function(self)
                    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
                end)
                itemRows[index] = row
            end
            row:SetPoint("TOPLEFT", 0, -(index - 1) * 40)
            row.reward = item
            row.title:SetText(item.name)
            local count = #entry.sources
            row.meta:SetText(count == 1 and entry.sources[1].quest.title or (count .. " quest sources"))
            row.icon:SetTexture(C_Item.GetItemIconByID(item.id) or itemFallbackIcon)
            row.background:SetColorTexture(unpack(entry == selection and colors.selected or colors.card))
            row:SetScript("OnClick", function() config.selectItem(item.id) end)
            row:Show()
        end
        resetScroll(listScroll, list, message and 32 or #entries * 40, offset or 0)

        local item = selection and selection.item
        local sourceOffset = item and selectedId == item.id and sourceScroll:GetVerticalScroll() or 0
        selectedId = item and item.id
        sourceTitle:SetText(item and item.name or "")
        sourceMeta:SetPoint("TOPLEFT", 2, -(sourceTitle:GetStringHeight() + 10))
        sourceMeta:SetText(item and ("Item #" .. item.id .. (item.level and ("  /  Requires level " .. item.level) or ""))
            or "Select an item to see the quests that award it.")
        local y = sourceTitle:GetStringHeight() + sourceMeta:GetStringHeight() + 24
        if selection then
            for index, step in ipairs(selection.sources) do
                local quest = step.quest
                local row = sourceRows[index] or makeButton(sources)
                sourceRows[index] = row
                row:SetPoint("TOPLEFT", 2, -y)
                row:SetSize(sourceWidth - 4, 42)
                row.title:SetWidth(sourceWidth - 20)
                row.meta:SetWidth(sourceWidth - 20)
                row.title:SetText(quest.title)
                row.meta:SetText("Open chain  /  #" .. quest.id .. (quest.level and ("  /  Level " .. quest.level) or ""))
                row:SetScript("OnClick", function() callbacks.openQuest(quest.id, step.destination) end)
                row:Show()
                y = y + 46
            end
        end
        resetScroll(sourceScroll, sources, y, sourceOffset)
    end

    return frame, query, category, listScroll, showItems
end

function Window.New(callbacks)
    local frame = CreateFrame("Frame", "ForeverQuestChainWindow", UIParent, "PortraitFrameTemplate")
    frame:SetSize(1000, 622)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetTitle("QuestChain")
    frame:SetPortraitToAsset("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
    frame:Hide()
    UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 60, -1)
    header:SetPoint("TOPRIGHT", -28, -1)
    header:SetHeight(21)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", -1, 1)
    footer:SetHeight(42)
    footer.minTabWidth = 92
    local catalogTab = CreateFrame("Button", nil, footer, "PanelTabButtonTemplate")
    catalogTab:SetText("Browse")
    catalogTab:SetPoint("TOPLEFT", 13, -2)
    local chainTab = CreateFrame("Button", nil, footer, "PanelTabButtonTemplate")
    chainTab:SetText("Chain")
    local rewardsTab = CreateFrame("Button", nil, footer, "PanelTabButtonTemplate")
    rewardsTab:SetText("Rewards")
    footer.Tabs = { catalogTab, chainTab, rewardsTab }
    PanelTemplates_SetNumTabs(footer, #footer.Tabs)
    PanelTemplates_SetTabEnabled(footer, 2, false)

    local bodyTop, bodyHeight = 56, 513
    local rewardPage, rewardQuery, rewardCategory, rewardScroll, showRewardItems =
        createRewardPage(frame, bodyTop, bodyHeight, callbacks)
    local chainBody, chainScroll, chainWidth, chainPanel =
        panel(frame, 14, bodyTop, 650, bodyHeight, "QUEST TIMELINE")
    chainScroll:SetPoint("TOPLEFT", 10, -85)
    local chainTitle = label(chainPanel, "GameFontNormalHuge", colors.text, 12, 30, chainWidth, "")
    chainTitle:SetWordWrap(false)
    local chainContext = label(chainPanel, "GameFontHighlightSmall", colors.muted, 12, 59, chainWidth, "")
    local detailBody, detailScroll, detailWidth, detailPanel =
        panel(frame, 674, bodyTop, 312, bodyHeight, "Quest Details", true)
    local catalog = CreateFrame("Frame", nil, frame)
    local catalogWidth, resultsTop = 972, 85
    catalog:SetPoint("TOPLEFT", 14, -bodyTop)
    catalog:SetSize(catalogWidth, bodyHeight)
    label(catalog, "GameFontNormalLarge", colors.accent, 12, 9, 260, "Quest catalog")

    local search = CreateFrame("EditBox", nil, catalog, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", 19, -48)
    search:SetSize(443, 24)
    search:SetAutoFocus(false)
    search:SetMaxLetters(100)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local hint = label(catalog, "GameFontDisableSmall", colors.muted, 23, 54, 420, "Quest name or ID")
    local find = makeControl(catalog, "Go", 74)
    find:SetPoint("LEFT", search, "RIGHT", 10, 0)
    local function runSearch()
        callbacks.search(search:GetText())
        search:ClearFocus()
    end
    find:SetScript("OnClick", runSearch)
    search:SetScript("OnEnterPressed", runSearch)
    search:SetScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
    end)

    local function modeButton(x, title, browseMode)
        local button = makeControl(catalog, title, 106)
        button:SetPoint("TOPLEFT", x, -8)
        button:SetScript("OnClick", function() callbacks.setBrowseMode(browseMode) end)
        return button
    end
    local searchMode = modeButton(254, "Search", false)
    local browseMode = modeButton(366, "By category", true)
    searchMode:Disable()

    local kindMenu = makeBrowseMenu(catalog, 12, 48, 168)
    kindMenu:SetupMenu(function(_, menu)
        for _, option in ipairs(callbacks.browseKinds) do
            local key = option.key
            menu:CreateRadio(option.name, function() return callbacks.browseKind() == key end,
                function() callbacks.selectBrowseKind(key) end)
        end
    end)
    local categoryMenu = makeBrowseMenu(catalog, 200, 48, 310)
    local hideCompleted = CreateFrame("CheckButton", nil, catalog, "UICheckButtonTemplate")
    hideCompleted:SetPoint("TOPLEFT", 524, -48)
    hideCompleted:SetSize(22, 22)
    hideCompleted.Text:SetText("Hide completed")
    hideCompleted.Text:SetTextColor(unpack(colors.muted))
    hideCompleted:SetScript("OnClick", function(self)
        callbacks.setCompletedFilter(self:GetChecked() and "incomplete" or nil)
    end)
    local completedOnly = false
    local showCompleted = makeControl(catalog, "Show completed", 130)
    showCompleted:SetPoint("TOPLEFT", 680, -48)
    showCompleted:SetScript("OnClick", function()
        callbacks.setCompletedFilter(not completedOnly and "completed" or nil)
    end)
    kindMenu:Hide()
    categoryMenu:Hide()
    hideCompleted:Hide()
    showCompleted:Hide()

    local resultBody, resultScroll, resultWidth, resultPanel, resultTitle =
        panel(catalog, 0, resultsTop, catalogWidth, bodyHeight - resultsTop, "SEARCH RESULTS")
    resultScroll:SetPoint("TOPLEFT", 10, -58)
    local idX, levelX, zoneX, statusX = 465, 550, 618, 796
    label(resultPanel, "GameFontNormalSmall", colors.muted, 18, 37, idX - 20, "Quest")
    label(resultPanel, "GameFontNormalSmall", colors.muted, idX + 10, 37, 100, "Quest ID")
    label(resultPanel, "GameFontNormalSmall", colors.muted, levelX + 10, 37, 90, "Level")
    local zoneTitle = label(resultPanel, "GameFontNormalSmall", colors.muted, zoneX + 10, 37, statusX - zoneX - 8, "Zone")
    local statusTitle = label(resultPanel, "GameFontNormalSmall", colors.accent, statusX + 10, 37, resultWidth - statusX, "Quest log")
    local nextPage = makeControl(resultPanel, "Next page", 88)
    nextPage:SetPoint("TOPRIGHT", -25, -5)
    local previousPage = makeControl(resultPanel, "Previous page", 101)
    previousPage:SetPoint("TOPRIGHT", -214, -5)
    local pageText = font(resultPanel, "GameFontHighlightSmall", colors.muted)
    pageText:SetPoint("RIGHT", nextPage, "LEFT", -4, 0)
    pageText:SetWidth(93)
    pageText:SetJustifyH("CENTER")
    nextPage:SetScript("OnClick", function() callbacks.browsePage(1) end)
    previousPage:SetScript("OnClick", function() callbacks.browsePage(-1) end)
    local function setPageControls(page, pageCount)
        local paged = pageCount and pageCount > 1
        nextPage:SetShown(paged == true)
        previousPage:SetShown(paged == true)
        pageText:SetShown(paged == true)
        if paged then
            nextPage:SetEnabled(page < pageCount)
            previousPage:SetEnabled(page > 1)
            pageText:SetText(("Page %d of %d"):format(page, pageCount))
        end
    end
    setPageControls()
    local panHint = label(chainPanel, "GameFontHighlightSmall", colors.muted, chainWidth - 126, 12, 150, "Shift+wheel to pan")
    panHint:SetJustifyH("RIGHT")
    panHint:Hide()
    local scrollTimeline = chainScroll:GetScript("OnMouseWheel")
    chainScroll:SetScript("OnMouseWheel", function(self, delta)
        local horizontalRange = self:GetHorizontalScrollRange()
        if horizontalRange > 0 and IsShiftKeyDown() then
            local offset = self:GetHorizontalScroll() - 96 * delta
            self:SetHorizontalScroll(math.max(0, math.min(offset, horizontalRange)))
        else
            scrollTimeline(self, delta)
        end
    end)
    local chainLines = CreateFrame("Frame", nil, chainBody)
    chainLines:SetAllPoints()
    local resultRows, chainRows, connectors, detailLines, rewardRows, locationButtons = {}, {}, {}, {}, {}, {}
    local detailId
    local resultMessage = label(resultBody, "GameFontHighlightSmall", colors.muted, 2, 4, resultWidth - 4,
        "Search by name or quest ID.")
    local chainMessage = label(chainBody, "GameFontHighlightSmall", colors.muted, 2, 4, chainWidth - 4, "")
    local rewardSummary = CreateFrame("Frame", nil, detailBody)
    rewardSummary:SetSize(detailWidth - 4, 50)
    rewardSummary:Hide()
    local metricWidth = (detailWidth - 4) / 2
    label(rewardSummary, "QuestFont", colors.inkHeading, 10, 7, metricWidth - 12, "XP")
    label(rewardSummary, "QuestFont", colors.inkHeading, metricWidth + 10, 7, metricWidth - 12, "Coin")
    local rewardXP = label(rewardSummary, "QuestFont", colors.ink, 10, 24, metricWidth - 12, "")
    local rewardCoin = label(rewardSummary, "QuestFont", colors.ink, metricWidth + 10, 24, metricWidth - 12, "")
    resetScroll(resultScroll, resultBody, 32, 0)
    resetScroll(chainScroll, chainBody, 32, 0)
    resetScroll(detailScroll, detailBody, 32, 0)

    local window = {}
    local browsing = false

    local function showPage(page)
        local open, chain = page == "browse", page == "chain"
        catalog:SetShown(open)
        chainPanel:SetShown(chain)
        detailPanel:SetShown(chain)
        rewardPage:SetShown(page == "rewards")
        rewardQuery:ClearFocus()
        PanelTemplates_SetTab(footer, open and 1 or (chain and 2 or 3))
        if open and not browsing and frame:IsShown() then
            search:SetFocus()
        else
            search:ClearFocus()
        end
    end

    function window:SetCatalogOpen(open)
        showPage(open and "browse" or "chain")
    end

    catalogTab:SetScript("OnClick", function() window:SetCatalogOpen(true) end)
    chainTab:SetScript("OnClick", function() window:SetCatalogOpen(false) end)
    rewardsTab:SetScript("OnClick", function()
        showPage("rewards")
        callbacks.rewardPage.open()
    end)
    window:SetCatalogOpen(true)

    function window:SetBrowseMode(enabled)
        browsing = enabled
        search:ClearFocus()
        search:SetShown(not enabled)
        find:SetShown(not enabled)
        hint:SetShown(not enabled and search:GetText() == "")
        kindMenu:SetShown(enabled)
        categoryMenu:SetShown(enabled)
        hideCompleted:SetShown(enabled)
        showCompleted:SetShown(enabled)
        if enabled then
            browseMode:Disable()
            searchMode:Enable()
        else
            browseMode:Enable()
            searchMode:Disable()
        end
        resultTitle:SetText(enabled and "BROWSE QUESTS" or "SEARCH RESULTS")
        zoneTitle:SetText(enabled and "Type / Progress" or "Zone")
        statusTitle:SetText(enabled and "Status" or "Quest log")
        if not enabled and catalog:IsShown() then search:SetFocus() end
    end

    function window:SetCompletedFilter(filter)
        completedOnly = filter == "completed"
        hideCompleted:SetChecked(filter == "incomplete")
        showCompleted:SetText(completedOnly and "Show all" or "Show completed")
    end

    function window:SetBrowseCategories(options, prompt)
        setupCategoryMenu(categoryMenu, options, prompt, callbacks.browseCategory, callbacks.selectBrowseCategory)
    end

    function window:SetRewardCategories(options, prompt)
        setupCategoryMenu(rewardCategory, options, prompt, callbacks.rewardPage.category, callbacks.rewardPage.selectCategory)
    end

    function window:ShowRewardItems(entries, selection, message, offset)
        showRewardItems(entries, selection, message, offset)
    end

    function window:RewardOffset()
        return rewardScroll:GetVerticalScroll()
    end

    function window:ResultOffset()
        return resultScroll:GetVerticalScroll()
    end

    function window:Show()
        if not frame:IsShown() then
            frame:SetScale(math.min(1, UIParent:GetWidth() / 1020, UIParent:GetHeight() / 642))
            frame:Show()
            if catalog:IsShown() and not browsing then
                search:SetFocus()
            end
        end
        frame:Raise()
    end

    function window:Toggle()
        if frame:IsShown() then
            search:ClearFocus()
            rewardQuery:ClearFocus()
            frame:Hide()
        else
            self:Show()
        end
    end

    local function startResults(message)
        hideAll(resultRows)
        resultMessage:SetText(message or "")
        resultMessage:SetShown(message ~= nil)
        return message and resultMessage:GetStringHeight() + 12 or 0
    end

    local function showResultRow(index, y, entry)
        local row = resultRows[index]
        if not row then
            row = makeButton(resultBody)
            row.title:SetWordWrap(true)
            row.title:SetMaxLines(2)
            row.meta:ClearAllPoints()
            row.meta:SetPoint("TOPLEFT", zoneX, -8)
            row.meta:SetWidth(statusX - zoneX - 8)
            row.questId = label(row, "GameFontHighlightSmall", colors.muted, idX, 8, levelX - idX - 8, "")
            row.level = label(row, "GameFontHighlightSmall", colors.muted, levelX, 8, zoneX - levelX - 8, "")
            row.logStatus = label(row, "GameFontHighlight", colors.muted, statusX, 7, resultWidth - statusX - 8, "")
            resultRows[index] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row.title:SetWidth(idX - 16)
        row.title:SetText(entry.title)
        row.questId:SetText(entry.id and ("#" .. entry.id) or "")
        row.level:SetText(entry.level and tostring(entry.level) or "")
        row.meta:SetText(entry.detail or "")
        local status = statuses[entry.logStatus or (entry.id and callbacks.questLogStatus(entry.id))]
        row.logStatus:SetText(status and status[1] or (entry.id and "Not in log" or ""))
        if status then
            row.logStatus:SetTextColor(status[2], status[3], status[4])
        else
            row.logStatus:SetTextColor(unpack(colors.muted))
        end
        row:SetScript("OnClick", entry.action)
        local height = math.max(29, row.title:GetStringHeight() + 14)
        row:SetSize(resultWidth, height)
        row:Show()
        return y + height + 2
    end

    function window:ShowResults(results, message, offset)
        setPageControls()
        local count = math.min(#results, 80)
        if not message and #results > count then
            message = ("First %d of %d matches"):format(count, #results)
        end
        local y = startResults(message)
        for index = 1, count do
            local quest = results[index]
            y = showResultRow(index, y, {
                title = quest.title, id = quest.id, level = quest.level, detail = quest.zone,
                action = function() callbacks.openQuest(quest.id) end,
            })
        end
        resetScroll(resultScroll, resultBody, y, offset or 0)
    end

    function window:ShowBrowse(entries, message, offset, page, pageCount)
        setPageControls(page, pageCount)
        local y = startResults(message)
        for index, entry in ipairs(entries) do
            y = showResultRow(index, y, entry)
        end
        resetScroll(resultScroll, resultBody, y, offset or 0)
    end

    function window:ShowChain(view, selectedId, statusesById, scrollToId)
        if chainTab.isDisabled then PanelTemplates_SetTabEnabled(footer, 2, true) end
        local hasParent, optionalSource, structural = {}, {}, {}
        for _, edge in ipairs(view.edges) do
            if edge.kind == "breadcrumb" or edge.kind == "substitute" then
                optionalSource[edge.fromId] = true
            else
                hasParent[edge.toId], structural[edge.fromId] = true, true
            end
        end
        local root = view.quests[1]
        for _, quest in ipairs(view.quests) do
            if not hasParent[quest.id] and (structural[quest.id] or not optionalSource[quest.id]) then
                root = quest
                break
            end
        end
        local count = #view.quests
        chainTitle:SetText(root and root.title or "")
        chainContext:SetText(count == 1 and "1 quest" or (count .. " quests  /  Top to bottom"))
        local offset = chainScroll:GetVerticalScroll()
        local horizontalOffset = chainScroll:GetHorizontalScroll()
        hideAll(chainRows)
        hideAll(connectors)
        chainMessage:Hide()
        local layout = ns.Timeline.Layout(view, chainWidth)
        chainBody:SetWidth(layout.width)
        panHint:SetShown(layout.width > chainWidth)

        local notices = {}
        if #view.missingIds > 0 then
            notices[#notices + 1] = "Some quest links are missing."
        end
        if layout.hasUnorderedLinks then
            notices[#notices + 1] = "Some quest links could not be ordered."
        end
        if #view.omittedIds > 0 then
            notices[#notices + 1] = "More steps are linked to this chain."
        end
        local top = 4
        if #notices > 0 then
            chainMessage:SetText(table.concat(notices, "\n"))
            chainMessage:Show()
            top = top + chainMessage:GetStringHeight() + 12
        end

        for index, quest in ipairs(view.quests) do
            local id = quest.id
            local row = chainRows[index] or makeTimelineButton(chainBody)
            chainRows[index] = row
            local card = layout.cards[id]
            local status = statuses[statusesById[id].status]
            local allCount, anyCount = #(quest.allOf or {}), #(quest.anyOf or {})
            local note = layout.notes[id] or ("#" .. id)
            if allCount > 0 and anyCount > 0 then
                note = "Requirements unclear"
            elseif allCount > 1 then
                note = "All required"
            elseif anyCount > 1 then
                note = "Any one required"
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", card.x, -(top + card.y))
            row:SetSize(card.width, card.height)
            row.title:SetWidth(card.width - 16)
            row.meta:SetWidth(card.width - 16)
            row.note:SetWidth(card.width - 16)
            row.title:SetText(quest.title)
            row.meta:SetText(status[1])
            row.meta:SetTextColor(status[2], status[3], status[4])
            row.note:SetText(note)
            row.note:Show()
            row.statusMark:SetColorTexture(status[2], status[3], status[4])
            row.statusMark:Show()
            row.background:SetColorTexture(unpack(id == selectedId and colors.selected or colors.card))
            row:SetBackdropBorderColor(unpack(id == selectedId and colors.connector or colors.edge))
            row:SetScript("OnClick", function() callbacks.selectStep(id) end)
            row:Show()
            if id == scrollToId then
                offset = top + card.y - chainScroll:GetHeight() / 3
                horizontalOffset = card.center - chainWidth / 2
            end
        end

        for index, segment in ipairs(layout.segments) do
            local texture = connectors[index] or chainLines:CreateTexture(nil, "ARTWORK")
            connectors[index] = texture
            texture:SetColorTexture(unpack(segment.optional and colors.optional or colors.connector))
            texture:ClearAllPoints()
            texture:SetPoint("TOPLEFT", segment.x1 - 0.75, -(top + segment.y1 - 0.75))
            texture:SetSize(segment.x2 - segment.x1 + 1.5, segment.y2 - segment.y1 + 1.5)
            texture:Show()
        end

        local y = top + layout.height + 8
        for index = 1, math.min(#view.omittedIds, 12) do
            local id = view.omittedIds[index]
            local rowIndex = #view.quests + index
            local row = chainRows[rowIndex] or makeTimelineButton(chainBody)
            chainRows[rowIndex] = row
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 26, -y)
            row:SetSize(chainWidth - 26, 32)
            row.title:SetWidth(chainWidth - 42)
            row.title:SetText("Open linked quest #" .. id)
            row.meta:SetText("")
            row.note:Hide()
            row.statusMark:Hide()
            row.background:SetColorTexture(unpack(colors.card))
            row:SetBackdropBorderColor(unpack(colors.edge))
            row:SetScript("OnClick", function() callbacks.openQuest(id) end)
            row:Show()
            y = y + 36
        end
        resetScroll(chainScroll, chainBody, y, offset)
        chainScroll:SetHorizontalScroll(math.max(0, math.min(horizontalOffset, chainScroll:GetHorizontalScrollRange())))
    end

    function window:ShowDetails(quest, rewards, requirement)
        local offset = detailId == quest.id and detailScroll:GetVerticalScroll() or 0
        detailId = quest.id
        hideAll(detailLines)
        hideAll(rewardRows)
        hideAll(locationButtons)
        local y, textCount, itemCount, locationCount = 0, 0, 0, 0
        local function text(value, heading, title)
            textCount = textCount + 1
            local normal = detailLines[textCount]
            if not normal then
                normal = font(detailBody, "QuestFont", colors.ink)
                detailLines[textCount] = normal
            end
            normal:SetFontObject(title and QuestTitleFont or QuestFont)
            normal:SetTextColor(unpack(heading and colors.inkHeading or colors.ink))
            normal:ClearAllPoints()
            normal:SetPoint("TOPLEFT", 2, -y)
            normal:SetWidth(detailWidth - 4)
            normal:SetText(value)
            normal:Show()
            y = y + normal:GetStringHeight() + (heading and 6 or 8)
        end
        local function listLocations(heading, locations)
            text(heading, true)
            if #locations == 0 then
                text("Unavailable")
            end
            for _, location in ipairs(locations) do
                local value = location.name
                if location.zone then
                    value = value .. "  /  " .. location.zone
                end
                if location.x then
                    value = value .. ("  %.1f, %.1f"):format(location.x, location.y)
                end
                text(value)
                if location.mapId then
                    locationCount = locationCount + 1
                    local button = locationButtons[locationCount] or makeControl(detailBody, "Show on map", 108)
                    locationButtons[locationCount] = button
                    button:SetPoint("TOPLEFT", 2, -y)
                    button:SetScript("OnClick", function()
                        if ns.Map.Show(location) then
                            frame:Hide()
                        else
                            print("QuestChain: The world map could not open to this location.")
                        end
                    end)
                    button:Show()
                    y = y + 32
                end
            end
        end
        local function rewardField(field, formatValue)
            if field.state == "known" then
                return formatValue(field.value)
            end
            return field.state == "loading" and "Loading" or "Unavailable"
        end
        local function money(copper)
            return ("%dg %02ds %02dc"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
        end
        local function items(heading, field)
            text(heading, true)
            if field.state ~= "known" then
                text(field.state == "loading" and "Loading" or "Unavailable")
                return
            end
            if #field.value == 0 then
                text("None")
            end
            for _, item in ipairs(field.value) do
                itemCount = itemCount + 1
                local row = rewardRows[itemCount]
                if not row then
                    row = CreateFrame("Button", nil, detailBody, "LargeItemButtonTemplate")
                    row:SetSize(detailWidth - 4, 41)
                    row.NameFrame:SetAtlas("QuestItemBorder")
                    row.NameFrame:ClearAllPoints()
                    row.NameFrame:SetPoint("TOPLEFT", row.Icon, "TOPRIGHT", 6, 0)
                    row.NameFrame:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 2)
                    row.Name:ClearAllPoints()
                    row.Name:SetPoint("LEFT", row.NameFrame, "LEFT", 8, 0)
                    row.Name:SetPoint("RIGHT", row.NameFrame, "RIGHT", -8, 0)
                    row:SetScript("OnEnter", showTooltip)
                    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    row:SetScript("OnHide", function(self)
                        if GameTooltip:IsOwned(self) then
                            GameTooltip:Hide()
                        end
                    end)
                    rewardRows[itemCount] = row
                end
                row.reward = item
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 2, -y)
                row.Icon:SetTexture(item.icon or C_Item.GetItemIconByID(item.id) or itemFallbackIcon)
                row.Name:SetText(itemName(item))
                row.Count:SetText(item.quantity > 1 and tostring(item.quantity) or "")
                row:Show()
                y = y + 46
            end
        end

        text(quest.title, true, true)
        local context = "#" .. quest.id .. (quest.level and ("  /  Level " .. quest.level) or "")
        text(context .. (quest.zone and ("  /  " .. quest.zone) or ""))
        y = y + 6
        text("Rewards", true)
        rewardSummary:SetPoint("TOPLEFT", 2, -y)
        rewardXP:SetText(rewardField(rewards.xp, tostring))
        rewardCoin:SetText(rewardField(rewards.copper, money))
        rewardSummary:Show()
        y = y + rewardSummary:GetHeight() + 12
        local guaranteed, choices = rewards.guaranteed, rewards.choices
        if guaranteed.state == "known" and #guaranteed.value == 0 and choices.state == "known" and #choices.value == 0 then
            text("No item rewards")
        else
            items("Guaranteed items", guaranteed)
            items("Choose one", choices)
        end
        y = y + 8
        text("Objectives", true)
        text(#quest.objectives > 0 and table.concat(quest.objectives, "\n") or "Unavailable")
        if requirement then
            text("Prerequisites", true)
            text(requirement)
        end
        listLocations("Starts at", quest.starters)
        listLocations("Turns in at", quest.finishers)
        resetScroll(detailScroll, detailBody, y, offset)
    end

    return window
end
