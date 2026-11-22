local _, ns = ...

local RewardPage = {}
ns.RewardPage = RewardPage

local Widgets = ns.Widgets
local colors = Widgets.colors
local itemFallbackIcon = Widgets.itemFallbackIcon
local panelInset = Widgets.panelInset
local label = Widgets.label
local font = Widgets.font
local panel = Widgets.panel
local makeButton = Widgets.makeButton
local hideAll = Widgets.hideAll
local resetScroll = Widgets.resetScroll
local updateScroll = Widgets.updateScroll
local showTooltip = Widgets.showTooltip
local tryLinkReward = Widgets.tryLinkReward

function RewardPage.New(parent, top, width, height, callbacks)
    local frame = CreateFrame("Frame", nil, parent, "ForeverQuestChainRewardCatalogTemplate")
    frame:SetPoint("TOPLEFT", 14, -top)
    frame:SetSize(width, height)
    local query, hint = frame.SearchBox, frame.SearchHint
    query:SetScript("OnTextChanged", function(self)
        local value = self:GetText()
        hint:SetShown(value == "")
        if not query.updating then callbacks.search(value) end
    end)
    query:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    query:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local filtersHeight, sourcesWidth, gap = 85, 342, 10
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

    local page = { frame = frame }

    function page:Render(entries, selection, message, offset, restoredSourceOffset)
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
                row:SetScript("OnHide", Widgets.hideOwnedTooltip)
                row:SetScript("OnClick", function(button)
                    if not tryLinkReward(button) then callbacks.selectItem(button.reward.id) end
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
        if restoredSourceOffset ~= nil then sourceOffset = restoredSourceOffset end
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

    function page:Resize(newWidth, newHeight)
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

    function page:SetQuery(value)
        query.updating = true
        query:SetText(value)
        query.updating = nil
    end

    function page:ClearFocus()
        query:ClearFocus()
    end

    function page:Offset()
        return listScroll:GetVerticalScroll()
    end

    function page:SourceOffset()
        return sourceScroll:GetVerticalScroll()
    end

    return page
end
