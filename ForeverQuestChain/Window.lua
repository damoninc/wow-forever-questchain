local _, ns = ...

local Window = {}
ns.Window = Window

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

local function panel(parent, x, top, width, height, heading)
    local frame = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    frame:SetPoint("TOPLEFT", x, -top)
    frame:SetSize(width, height)
    local title = label(frame, "GameFontNormalSmall", colors.accent, 12, 12, width - 24, heading)
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
    local contentWidth = width - panelInset
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

local function makeBreadcrumb(parent, current)
    local button = CreateFrame("Button", nil, parent)
    local color = current and colors.text or colors.accent
    local text = font(button, "GameFontNormal", color)
    text:SetPoint("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    text:SetMaxLines(1)
    button.crumbText = text
    button:SetHeight(22)
    button:SetScript("OnEnter", function() text:SetTextColor(unpack(current and colors.accent or colors.text)) end)
    local function resetColor() text:SetTextColor(unpack(color)) end
    button:SetScript("OnLeave", resetColor)
    button:SetScript("OnHide", resetColor)
    return button
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
    row.partyStatus = label(row, "GameFontHighlightSmall", partyTextColor, x, y, width, "")
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
    local button = makeButton(parent, "BackdropTemplate")
    button:SetBackdrop(cardEdge)
    button.title:SetWordWrap(true)
    button.title:SetMaxLines(2)
    button.meta:ClearAllPoints()
    button.meta:SetPoint("TOPLEFT", 8, -35)
    button.note = label(button, "GameFontHighlightSmall", colors.muted, 8, 49, 1, "")
    button.note:SetWordWrap(false)
    addPartyStatus(button, 8, 63, 96)
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

local function questAtlas(parent, layer, atlas)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetAtlas(atlas, true)
    return texture
end

local function createQuestDetails(parent, top, width, height)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPRIGHT", -14, -top)
    frame:SetSize(width, height)
    local paper = questAtlas(frame, "BACKGROUND", "QuestDetailsBackgrounds")
    paper:SetPoint("TOPLEFT")
    paper:SetPoint("BOTTOMRIGHT", -20, 0)
    local header = questAtlas(frame, "BORDER", "questlog-reward-top-frame")
    local headerHeight = 43
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT", -20, 0)
    header:SetHeight(headerHeight)
    local border = CreateFrame("Frame", nil, frame, "QuestLogBorderFrameTemplate")
    border:SetPoint("BOTTOMRIGHT", -17, -6)
    frame.BackButton = makeControl(frame, BACK or "Back", 90)
    frame.BackButton:SetPoint("TOPLEFT", 11, -10)

    local contentWidth = width - 26
    local scroll = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 3, -headerHeight - 7)
    scroll:SetPoint("BOTTOMRIGHT", -23, 7)
    scroll:EnableMouseWheel(true)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(contentWidth, 1)
    scroll:SetScrollChild(body)

    local tray = CreateFrame("Frame", nil, body)
    tray:SetSize(contentWidth, 1)
    tray:SetPoint("BOTTOMLEFT")
    fill(tray, "BACKGROUND", 0.20, 0.11, 0.06)
    local trayTop = questAtlas(tray, "BORDER", "questlog-reward-header-top")
    trayTop:SetPoint("TOPLEFT")
    trayTop:SetPoint("TOPRIGHT")
    local trayBottom = questAtlas(tray, "BORDER", "questlog-reward-bottom")
    trayBottom:SetPoint("BOTTOMLEFT")
    trayBottom:SetPoint("BOTTOMRIGHT")
    local trayBackground = tray:CreateTexture(nil, "BACKGROUND", nil, 1)
    trayBackground:SetAtlas("questlog-reward-tile-vertical")
    trayBackground:SetPoint("TOPLEFT", trayTop, "BOTTOMLEFT")
    trayBackground:SetPoint("BOTTOMRIGHT")
    local rewardTextColor = { 0.902, 0.788, 0.671 }
    local trayTitle = label(tray, "QuestFont_Huge", rewardTextColor, 0, 22, contentWidth, REWARDS or "Rewards")
    trayTitle:SetJustifyH("CENTER")
    local choose = font(tray, "QuestMapRewardsFont", rewardTextColor)
    local receive = font(tray, "QuestMapRewardsFont", rewardTextColor)
    local detailLines, rewardRows, locationButtons = {}, {}, {}
    local detailId, contentHeight

    local function layoutDetails(offset)
        if contentHeight then
            -- Let short details fill the viewport. The tray remains part of the scroll child.
            resetScroll(scroll, body, math.max(contentHeight, scroll:GetHeight()), offset)
        end
    end
    scroll:HookScript("OnSizeChanged", function(self) layoutDetails(self:GetVerticalScroll()) end)

    local function showDetails(_, quest, rewards, requirement, log)
        local offset = detailId == quest.id and scroll:GetVerticalScroll() or 0
        detailId = quest.id
        hideAll(detailLines)
        hideAll(rewardRows)
        hideAll(locationButtons)
        choose:Hide()
        receive:Hide()
        local contrast = QuestTextContrast
        local parchment = contrast and contrast.GetDefaultDetailsBackgroundAtlas()
        paper:SetAtlas(parchment or "QuestDetailsBackgrounds")
        local textColor = contrast and contrast.UseLightText() and colors.text or colors.ink
        local y, textCount, locationCount = 8, 0, 0
        local function text(value, style, gap)
            textCount = textCount + 1
            local line = detailLines[textCount] or font(body, "QuestFont", textColor)
            detailLines[textCount] = line
            line:SetFontObject(style or "QuestFont")
            line:SetTextColor(unpack(textColor))
            line:SetPoint("TOPLEFT", 8, -y)
            line:SetWidth(contentWidth - 16)
            line:SetText(value)
            line:Show()
            y = y + line:GetStringHeight() + (gap or 5)
        end
        local function listLocations(heading, locations)
            text(heading, "QuestTitleFont")
            if #locations == 0 then text("Unavailable") end
            for _, location in ipairs(locations) do
                local value = location.name
                if location.zone then value = value .. "  /  " .. location.zone end
                if location.x then value = value .. ("  %.1f, %.1f"):format(location.x, location.y) end
                text(value)
                if location.mapId then
                    locationCount = locationCount + 1
                    local button = locationButtons[locationCount] or makeControl(body, "Show on map", 108)
                    locationButtons[locationCount] = button
                    button:SetPoint("TOPLEFT", 8, -y)
                    button:SetScript("OnClick", function()
                        if ns.Map.Show(location) then
                            parent:Hide()
                        else
                            print("QuestChain: The world map could not open to this location.")
                        end
                    end)
                    button:Show()
                    y = y + 32
                end
            end
        end

        text(quest.title, "QuestTitleFont", 2)
        local objectiveText = log and log.objectiveText
        if not objectiveText or objectiveText == "" then
            objectiveText = #quest.objectives > 0 and table.concat(quest.objectives, "\n") or "Unavailable"
        end
        text(objectiveText, nil, 8)
        for _, objective in ipairs(log and log.progress or {}) do
            if objective.text and objective.text ~= "" and objective.type ~= "spell" and objective.type ~= "log" then
                local value = objective.finished and (objective.text .. " (" .. (COMPLETE or "Complete") .. ")")
                    or objective.text
                text(value, "QuestFontNormalSmall", 2)
            end
        end
        y = y + 12
        text(QUEST_DESCRIPTION or "Description", "QuestTitleFont", 2)
        local description = log and log.description
        text(description and description ~= "" and description or "Unavailable", nil, 15)
        local context = "#" .. quest.id .. (quest.level and ("  /  Level " .. quest.level) or "")
        text(context .. (quest.zone and ("  /  " .. quest.zone) or ""), "QuestFontNormalSmall", 10)
        if requirement then
            text("Prerequisites", "QuestTitleFont")
            text(requirement, nil, 12)
        end
        listLocations("Starts at", quest.starters)
        listLocations("Turns in at", quest.finishers)

        local rewardY, count, column = 53, 0, 0
        local function endRow()
            if column ~= 0 then
                rewardY = rewardY + 34
                column = 0
            end
        end
        local function rewardHeading(heading, value)
            endRow()
            heading:SetPoint("TOPLEFT", 8, -rewardY)
            heading:SetWidth(contentWidth - 16)
            heading:SetText(value)
            heading:Show()
            rewardY = rewardY + heading:GetStringHeight() + 5
        end
        local function rewardSlot(name, icon, item)
            count = count + 1
            local row = rewardRows[count]
            if not row then
                row = CreateFrame("Button", nil, tray, "SmallItemButtonTemplate")
                row:SetScript("OnClick", function(self) if self.reward then tryLinkReward(self) end end)
                row:SetScript("OnEnter", function(self) if self.reward then showTooltip(self) end end)
                row:SetScript("OnLeave", hideOwnedTooltip)
                row:SetScript("OnHide", hideOwnedTooltip)
                rewardRows[count] = row
            end
            row.reward = item
            row:SetPoint("TOPLEFT", 8 + column * 136, -rewardY)
            row.Icon:SetTexture(icon)
            row.Name:SetText(name)
            row.Count:SetText(item and item.quantity > 1 and tostring(item.quantity) or "")
            row:Show()
            column = column + 1
            if column == 2 then endRow() end
        end
        local function fieldStatus(field)
            return field.state == "loading" and "Loading" or "Unavailable"
        end
        local function hasItems(field)
            return field.state ~= "known" or #field.value > 0
        end
        local function rewardItems(field)
            if field.state ~= "known" then
                rewardSlot(fieldStatus(field), itemFallbackIcon)
                endRow()
                return
            end
            for _, item in ipairs(field.value) do
                rewardSlot(itemName(item), item.icon or C_Item.GetItemIconByID(item.id) or itemFallbackIcon, item)
            end
            endRow()
        end
        local function rewardAmount(field, icon, formatValue)
            if field.state ~= "known" then
                rewardSlot(fieldStatus(field), icon)
            elseif field.value > 0 then
                rewardSlot(formatValue(field.value), icon)
            end
        end

        local choices, guaranteed = rewards.choices, rewards.guaranteed
        local showChoices = hasItems(choices)
        if showChoices then
            rewardHeading(choose, REWARD_CHOICES or "Choose one:")
            rewardItems(choices)
        end
        local function money(copper)
            return GetMoneyString(copper, false, true)
        end
        if hasItems(guaranteed) or rewards.xp.value ~= 0 or rewards.copper.value ~= 0 then
            local heading = showChoices and REWARD_ITEMS or REWARD_ITEMS_ONLY
            rewardHeading(receive, heading or "You will receive:")
            rewardAmount(rewards.xp, "Interface\\Icons\\XP_Icon", BreakUpLargeNumbers)
            rewardAmount(rewards.copper, "Interface\\Icons\\inv_misc_coin_01", money)
            endRow()
            rewardItems(guaranteed)
        elseif not showChoices then
            rewardHeading(receive, "No rewards")
        end
        tray:SetHeight(rewardY + 12)
        contentHeight = y + 8 + tray:GetHeight()
        layoutDetails(offset)
    end

    return frame, showDetails
end

local function createRewardPage(parent, top, width, height, callbacks)
    local config = callbacks.rewardPage
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", 14, -top)
    frame:SetSize(width, height)
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

    local filtersHeight, sourcesWidth, gap = 63, 342, 10
    local listPanelWidth = width - sourcesWidth - gap
    local list, listScroll, listWidth, listPanel, listTitle =
        panel(frame, 0, filtersHeight, listPanelWidth, height - filtersHeight, "QUEST REWARDS")
    local sources, sourceScroll, sourceWidth, sourcePanel =
        panel(frame, listPanelWidth + gap, filtersHeight, sourcesWidth, height - filtersHeight, "REWARD SOURCES")
    sourcePanel:ClearAllPoints()
    sourcePanel:SetPoint("TOPRIGHT", 0, -filtersHeight)
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
                row.title:SetPoint("TOPRIGHT", -8, -6)
                row.meta:ClearAllPoints()
                row.meta:SetPoint("TOPLEFT", 42, -22)
                row.meta:SetPoint("TOPRIGHT", -8, -22)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetPoint("LEFT", 5, 0)
                row.icon:SetSize(28, 28)
                row:SetScript("OnEnter", showTooltip)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                row:SetScript("OnHide", function(self)
                    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
                end)
                row:SetScript("OnClick", function(self)
                    if not tryLinkReward(self) then config.selectItem(self.reward.id) end
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
                row:SetScript("OnClick", function() config.openQuest(quest.id, step.destination) end)
                row:Show()
                y = y + 46
            end
        end
        resetScroll(sourceScroll, sources, y, sourceOffset)
    end

    local function resize(newWidth, newHeight)
        local listOffset, sourceOffset = listScroll:GetVerticalScroll(), sourceScroll:GetVerticalScroll()
        local panelWidth = newWidth - sourcesWidth - gap
        frame:SetSize(newWidth, newHeight)
        listPanel:SetSize(panelWidth, newHeight - filtersHeight)
        sourcePanel:SetHeight(newHeight - filtersHeight)
        if listPanelWidth ~= panelWidth then
            listPanelWidth = panelWidth
            listWidth = panelWidth - panelInset
            list:SetWidth(listWidth)
            listMessage:SetWidth(listWidth - 4)
            for _, row in ipairs(itemRows) do row:SetWidth(listWidth) end
        end
        updateScroll(listScroll, listOffset)
        updateScroll(sourceScroll, sourceOffset)
    end

    return frame, query, category, listScroll, showItems, resize
end

local function createActiveChainsPage(parent, top, width, height, openQuest)
    local body, scroll, contentWidth, frame, title = panel(parent, 14, top, width, height, "ACTIVE CHAINS")
    local rows = {}
    local notice = label(body, "GameFontHighlightSmall", colors.muted, 6, 4, contentWidth - 12, "")

    local function showChains(_, entries, message)
        local offset = scroll:GetVerticalScroll()
        hideAll(rows)
        notice:SetText(message or "No active quest chains.")
        notice:SetShown(#entries == 0)
        title:SetText(message and "ACTIVE CHAINS" or ("ACTIVE CHAINS  /  %d"):format(#entries))
        for index, entry in ipairs(entries) do
            local row = rows[index]
            if not row then
                row = makeButton(body)
                row.title:SetPoint("TOPRIGHT", -8, -6)
                row.meta:SetPoint("TOPRIGHT", -8, -24)
                row:SetScript("OnClick", function(self)
                    openQuest(self.step.quest.id, self.step.destination)
                end)
                rows[index] = row
            end
            row.step = entry.step
            row:SetPoint("TOPLEFT", 0, -((index - 1) * 44 + 4))
            row:SetSize(contentWidth, 42)
            row.title:SetText(entry.title)
            local quest, log = entry.step.quest, entry.log
            local status = statuses[log.status]
            local active = entry.count == 1 and "1 active step" or (entry.count .. " active steps")
            local level = log.level or quest.level
            local context = (level and ("  /  Level " .. level) or "") .. (log.zone and ("  /  " .. log.zone) or "")
            row.meta:SetText(status[1] .. "  /  " .. active .. "  /  " .. quest.title .. " (#" .. quest.id .. ")" .. context)
            row.meta:SetTextColor(status[2], status[3], status[4])
            row:Show()
        end
        resetScroll(scroll, body, math.max(32, #entries * 44 + 4), offset)
    end

    local function resize(newWidth, newHeight)
        local offset = scroll:GetVerticalScroll()
        frame:SetSize(newWidth, newHeight)
        local newContentWidth = newWidth - panelInset
        if newContentWidth ~= contentWidth then
            contentWidth = newContentWidth
            body:SetWidth(contentWidth)
            notice:SetWidth(contentWidth - 12)
            for _, row in ipairs(rows) do row:SetWidth(contentWidth) end
        end
        updateScroll(scroll, offset)
    end

    return frame, showChains, resize
end

function Window.New(callbacks)
    local defaultWidth, defaultHeight = 1000, 622
    local minWidth, minHeight = 860, 460
    local bodyTop, bodyBottom, sideMargin, panelGap = 56, 53, 14, 10
    local detailWidth = 312
    local frame = CreateFrame("Frame", "ForeverQuestChainWindow", UIParent, "PortraitFrameTemplate")
    frame:SetSize(defaultWidth, defaultHeight)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetResizable(true)
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

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(20, 20)
    grip:SetPoint("BOTTOMRIGHT", -5, 5)
    grip:SetFrameLevel(frame:GetFrameLevel() + 10)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame:HookScript("OnHide", function() frame:StopMovingOrSizing() end)

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
    local activeChainsTab = CreateFrame("Button", nil, footer, "PanelTabButtonTemplate")
    activeChainsTab:SetText("Active Chains")
    footer.Tabs = { catalogTab, chainTab, rewardsTab, activeChainsTab }
    PanelTemplates_SetNumTabs(footer, #footer.Tabs)
    PanelTemplates_SetTabEnabled(footer, 2, false)

    local catalogWidth, bodyHeight = defaultWidth - 2 * sideMargin, defaultHeight - bodyTop - bodyBottom
    local rewardPage, rewardQuery, rewardCategory, rewardScroll, showRewardItems, resizeRewardPage =
        createRewardPage(frame, bodyTop, catalogWidth, bodyHeight, callbacks)
    local activeChainsPage, showActiveChains, resizeActiveChains =
        createActiveChainsPage(frame, bodyTop, catalogWidth, bodyHeight, callbacks.openQuest)
    local chainBody, chainScroll, chainWidth, chainPanel =
        panel(frame, sideMargin, bodyTop, catalogWidth - detailWidth - panelGap, bodyHeight, "QUEST TIMELINE")
    chainScroll:SetPoint("TOPLEFT", 10, -106)
    local chainTitle = label(chainPanel, "GameFontNormalHuge", colors.text, 12, 30, chainWidth, "")
    chainTitle:SetWordWrap(false)
    local chainContext = label(chainPanel, "GameFontHighlightSmall", colors.muted, 12, 59, chainWidth, "")
    local browseCrumb = makeBreadcrumb(chainPanel)
    setBreadcrumbText(browseCrumb, "Browse")
    browseCrumb:SetPoint("TOPLEFT", 12, -77)
    local kindSeparator = font(chainPanel, "GameFontHighlightSmall", colors.muted)
    kindSeparator:SetText("›")
    kindSeparator:SetPoint("LEFT", browseCrumb, "RIGHT", 8, 0)
    local kindCrumb = makeBreadcrumb(chainPanel)
    kindCrumb:SetPoint("LEFT", kindSeparator, "RIGHT", 8, 0)
    local categorySeparator = font(chainPanel, "GameFontHighlightSmall", colors.muted)
    categorySeparator:SetText("›")
    categorySeparator:SetPoint("LEFT", kindCrumb, "RIGHT", 8, 0)
    local categoryCrumb = makeBreadcrumb(chainPanel, true)
    categoryCrumb:SetPoint("LEFT", categorySeparator, "RIGHT", 8, 0)
    local earlierWidth = 155
    local earlierMenu = makeBrowseMenu(chainPanel, 0, 75, earlierWidth)
    earlierMenu:ClearAllPoints()
    earlierMenu:SetPoint("TOPRIGHT", -14, -75)
    earlierMenu:SetDefaultText("Earlier quests")
    local detailPanel, showDetails = createQuestDetails(frame, bodyTop, detailWidth, bodyHeight)
    local catalog = CreateFrame("Frame", nil, frame)
    local resultsTop = 85
    catalog:SetPoint("TOPLEFT", sideMargin, -bodyTop)
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
    local idX, levelX, zoneX, statusX
    local questHeading = label(resultPanel, "GameFontNormalSmall", colors.muted, 18, 37, 1, "Quest")
    local idHeading = label(resultPanel, "GameFontNormalSmall", colors.muted, 0, 37, 77, "Quest ID")
    local levelHeading = label(resultPanel, "GameFontNormalSmall", colors.muted, 0, 37, 60, "Level")
    local zoneTitle = label(resultPanel, "GameFontNormalSmall", colors.muted, 0, 37, 170, "Zone")
    local statusTitle = label(resultPanel, "GameFontNormalSmall", colors.accent, 0, 37, 140, "Quest log")
    local function layoutResultHeadings()
        idX, levelX, zoneX, statusX = resultWidth - 471, resultWidth - 386, resultWidth - 318, resultWidth - 140
        questHeading:SetWidth(idX - 20)
        idHeading:SetPoint("TOPLEFT", idX + 10, -37)
        levelHeading:SetPoint("TOPLEFT", levelX + 10, -37)
        zoneTitle:SetPoint("TOPLEFT", zoneX + 10, -37)
        statusTitle:SetPoint("TOPLEFT", statusX + 10, -37)
    end
    layoutResultHeadings()
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
    local panHint = font(chainPanel, "GameFontHighlightSmall", colors.muted)
    panHint:SetPoint("TOPRIGHT", -12, -12)
    panHint:SetWidth(150)
    panHint:SetText("Shift+wheel to pan")
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
    local resultRows, chainRows, connectors = {}, {}, {}
    local resultMessage = label(resultBody, "GameFontHighlightSmall", colors.muted, 2, 4, resultWidth - 4,
        "Search by name or quest ID.")
    local chainMessage = label(chainBody, "GameFontHighlightSmall", colors.muted, 2, 4, chainWidth - 4, "")
    resetScroll(resultScroll, resultBody, 32, 0)
    resetScroll(chainScroll, chainBody, 32, 0)

    local window = { ShowDetails = showDetails, ShowActiveChains = showActiveChains }
    local browsing = false
    local currentPage, backPage = "browse", "browse"
    local tabIndex = { browse = 1, chain = 2, rewards = 3, activeChains = 4 }

    local function showPage(page)
        currentPage = page
        local open, chain = page == "browse", page == "chain"
        catalog:SetShown(open)
        chainPanel:SetShown(chain)
        detailPanel:SetShown(chain)
        rewardPage:SetShown(page == "rewards")
        activeChainsPage:SetShown(page == "activeChains")
        rewardQuery:ClearFocus()
        PanelTemplates_SetTab(footer, tabIndex[page])
        if open and not browsing and frame:IsShown() then
            search:SetFocus()
        else
            search:ClearFocus()
        end
        if window:IsActiveChainsOpen() then callbacks.openActiveChains() end
    end

    function window:IsActiveChainsOpen()
        return currentPage == "activeChains" and frame:IsShown()
    end

    function window:SetCatalogOpen(open)
        if not open and currentPage ~= "chain" then
            backPage = currentPage == "activeChains" and "activeChains" or "browse"
        end
        showPage(open and "browse" or "chain")
    end

    browseCrumb:SetScript("OnClick", function() window:SetCatalogOpen(true) end)
    detailPanel.BackButton:SetScript("OnClick", function() showPage(backPage) end)
    catalogTab:SetScript("OnClick", function() window:SetCatalogOpen(true) end)
    chainTab:SetScript("OnClick", function() window:SetCatalogOpen(false) end)
    rewardsTab:SetScript("OnClick", function()
        showPage("rewards")
        callbacks.rewardPage.open()
    end)
    activeChainsTab:SetScript("OnClick", function() showPage("activeChains") end)
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
            kindMenu:GenerateMenu()
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
            local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
            local scale = math.min(1, screenWidth / (defaultWidth + 20), screenHeight / (defaultHeight + 20))
            local maxWidth = math.floor(screenWidth / scale + 0.5) - 20
            local maxHeight = math.floor(screenHeight / scale + 0.5) - 20
            frame:SetScale(scale)
            frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
            local width, height = frame:GetWidth(), frame:GetHeight()
            if width > maxWidth or height > maxHeight then
                frame:SetSize(math.min(width, maxWidth), math.min(height, maxHeight))
            end
            frame:Show()
            if self:IsActiveChainsOpen() then callbacks.openActiveChains() end
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

    local function layoutResultRow(row, y)
        row:SetPoint("TOPLEFT", 0, -y)
        row.title:SetWidth(idX - 16)
        row.questId:SetPoint("TOPLEFT", idX, -8)
        row.level:SetPoint("TOPLEFT", levelX, -8)
        row.meta:SetPoint("TOPLEFT", zoneX, -8)
        row.logStatus:SetPoint("TOPLEFT", statusX, -7)
        row.partyStatus:SetPoint("TOPLEFT", statusX, -24)
        local height = math.max(29, row.title:GetStringHeight() + 14)
        if row.partyNames then height = math.max(height, 24 + partyLineHeight) end
        row:SetSize(resultWidth, height)
        return y + height + 2
    end

    local function showResultRow(index, y, entry)
        local row = resultRows[index]
        if not row then
            row = makeButton(resultBody)
            row.title:SetWordWrap(true)
            row.title:SetMaxLines(2)
            row.meta:ClearAllPoints()
            row.meta:SetWidth(statusX - zoneX - 8)
            row.questId = label(row, "GameFontHighlightSmall", colors.muted, idX, 8, levelX - idX - 8, "")
            row.level = label(row, "GameFontHighlightSmall", colors.muted, levelX, 8, zoneX - levelX - 8, "")
            row.logStatus = label(row, "GameFontHighlight", colors.muted, statusX, 7, resultWidth - statusX - 8, "")
            addPartyStatus(row, statusX, 24, resultWidth - statusX - 8)
            resultRows[index] = row
        end
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
        setPartyStatus(row, entry.party)
        local nextY = layoutResultRow(row, y)
        row:Show()
        return nextY
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
                party = callbacks.partyOnQuest and callbacks.partyOnQuest(quest.id),
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

    local function showChainNavigation(context, view, layout, selectedId)
        local kind = context and context.kind
        local category = context and context.category
        kindSeparator:SetShown(kind ~= nil)
        kindCrumb:SetShown(kind ~= nil)
        categorySeparator:SetShown(category ~= nil)
        categoryCrumb:SetShown(category ~= nil)
        if kind then
            for _, option in ipairs(callbacks.browseKinds) do
                if option.key == kind then setBreadcrumbText(kindCrumb, option.name) end
            end
            kindCrumb:SetScript("OnClick", function()
                callbacks.openBrowseCategory(kind, category and category.key)
            end)
        end
        local earlier = ns.Timeline.EarlierSteps(layout, selectedId)
        if category then
            local trailWidth = browseCrumb:GetWidth() + kindCrumb:GetWidth()
                + kindSeparator:GetUnboundedStringWidth() + categorySeparator:GetUnboundedStringWidth()
            local menuWidth = #earlier > 0 and earlierWidth + 10 or 0
            local remaining = chainWidth + panelInset - 58 - trailWidth - menuWidth
            setBreadcrumbText(categoryCrumb, category.name, remaining)
            categoryCrumb:SetScript("OnClick", function() callbacks.openBrowseCategory(kind, category.key) end)
        end

        earlierMenu:SetShown(#earlier > 0)
        if #earlier > 0 then
            local titles = {}
            for _, quest in ipairs(view.quests) do titles[quest.id] = quest.title end
            earlierMenu:SetupMenu(function(_, menu)
                menu:SetScrollMode(280)
                for _, edge in ipairs(earlier) do
                    local id = edge.fromId
                    local title = titles[id] .. "  /  #" .. id
                    if edge.kind == "breadcrumb" or edge.kind == "substitute" then
                        title = title .. "  /  " .. layout.notes[id]
                    end
                    menu:CreateButton(title, function() callbacks.selectStep(id, id) end)
                end
            end)
        end
    end

    local lastView, lastSelected, lastStatuses, lastContext
    function window:ShowChain(view, selectedId, statusesById, scrollToId, context)
        lastView, lastSelected, lastStatuses, lastContext = view, selectedId, statusesById, context
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
        local partyById = {}
        if callbacks.partyOnQuest then
            for _, quest in ipairs(view.quests) do
                partyById[quest.id] = callbacks.partyOnQuest(quest.id)
            end
        end
        local layout = ns.Timeline.Layout(view, chainWidth, next(partyById) and partyLineHeight)
        showChainNavigation(context, view, layout, selectedId)
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
            setPartyStatus(row, partyById[id])
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
            setPartyStatus(row, nil)
            row.statusMark:Hide()
            row.background:SetColorTexture(unpack(colors.card))
            row:SetBackdropBorderColor(unpack(colors.edge))
            row:SetScript("OnClick", function() callbacks.openLinkedQuest(id) end)
            row:Show()
            y = y + 36
        end
        resetScroll(chainScroll, chainBody, y, offset)
        chainScroll:SetHorizontalScroll(math.max(0, math.min(horizontalOffset, chainScroll:GetHorizontalScrollRange())))
    end

    frame:HookScript("OnSizeChanged", function(_, width, height)
        local newWidth = math.floor(width + 0.5) - 2 * sideMargin
        local newHeight = math.floor(height + 0.5) - bodyTop - bodyBottom
        local widthChanged = catalogWidth ~= newWidth
        if not widthChanged and bodyHeight == newHeight then return end

        local resultOffset = resultScroll:GetVerticalScroll()
        local chainOffset = chainScroll:GetVerticalScroll()
        catalogWidth, bodyHeight = newWidth, newHeight
        catalog:SetSize(catalogWidth, bodyHeight)
        resultPanel:SetSize(catalogWidth, bodyHeight - resultsTop)
        local chainPanelWidth = catalogWidth - detailWidth - panelGap
        chainPanel:SetSize(chainPanelWidth, bodyHeight)
        detailPanel:SetHeight(bodyHeight)
        resizeRewardPage(catalogWidth, bodyHeight)
        resizeActiveChains(catalogWidth, bodyHeight)

        if widthChanged then
            resultWidth, chainWidth = catalogWidth - panelInset, chainPanelWidth - panelInset
            resultBody:SetWidth(resultWidth)
            resultMessage:SetWidth(resultWidth - 4)
            layoutResultHeadings()
            local y = resultMessage:IsShown() and resultMessage:GetStringHeight() + 12 or 0
            for _, row in ipairs(resultRows) do
                if not row:IsShown() then break end
                y = layoutResultRow(row, y)
            end
            resetScroll(resultScroll, resultBody, y, resultOffset)

            chainTitle:SetWidth(chainWidth)
            chainContext:SetWidth(chainWidth)
            chainMessage:SetWidth(chainWidth - 4)
            if lastView then
                updateScroll(chainScroll, chainOffset)
                window:ShowChain(lastView, lastSelected, lastStatuses, nil, lastContext)
            else
                chainBody:SetWidth(chainWidth)
                updateScroll(chainScroll, chainOffset)
            end
        else
            updateScroll(resultScroll, resultOffset)
            updateScroll(chainScroll, chainOffset)
        end
    end)

    return window
end
