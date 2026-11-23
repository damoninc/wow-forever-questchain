local _, ns = ...

ForeverQuestChainQuestListMixin = {}
local QuestList = ForeverQuestChainQuestListMixin

local Widgets = ns.Widgets
local colors = Widgets.colors
local statuses = Widgets.statuses
local panelInset = Widgets.panelInset
local partyLineHeight = Widgets.partyLineHeight
local font = Widgets.font
local label = Widgets.label
local makeButton = Widgets.makeButton
local setupCategoryMenu = Widgets.setupCategoryMenu
local addPartyStatus = Widgets.addPartyStatus
local setPartyStatus = Widgets.setPartyStatus
local hideAll = Widgets.hideAll
local updateScroll = Widgets.updateScroll
local resetScroll = Widgets.resetScroll

function QuestList.Initialize(catalog, catalogWidth, bodyHeight, callbacks)
    local browsing = false
    local resultsTop = 85
    catalog:SetSize(catalogWidth, bodyHeight)
    local catalogTitle, search = catalog.Heading, catalog.SearchBox
    local hint, find = catalog.SearchHint, catalog.Go
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local function runSearch()
        callbacks.search(search:GetText())
        search:ClearFocus()
    end
    find:SetScript("OnClick", runSearch)
    search:SetScript("OnEnterPressed", runSearch)
    search:SetScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
    end)

    local categoryMenu = catalog.CategoryMenu
    categoryMenu.Text:SetJustifyH("LEFT")
    local categoryHint, hideCompleted = catalog.CategoryHint, catalog.HideCompleted
    hideCompleted.Text:SetText("Hide completed")
    hideCompleted.Text:SetTextColor(unpack(colors.muted))
    hideCompleted:SetScript("OnClick", function(self)
        callbacks.setCompletedFilter(self:GetChecked() and "incomplete" or nil)
    end)
    local completedOnly = false
    local showCompleted = catalog.ShowCompleted
    showCompleted:SetScript("OnClick", function()
        callbacks.setCompletedFilter(not completedOnly and "completed" or nil)
    end)
    local showOutliers = catalog.ShowOutliers
    showOutliers.Text:SetText("Show outlier quests")
    showOutliers.Text:SetTextColor(unpack(colors.muted))
    showOutliers:SetHitRectInsets(0, -showOutliers.Text:GetStringWidth() - 6, 0, 0)
    showOutliers:SetScript("OnClick", function(self)
        callbacks.setShowOutliers(self:GetChecked())
    end)
    showOutliers:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Outlier quests")
        GameTooltip:AddLine("These quests are far below or above the typical quest levels for this location.",
            1, 1, 1, true)
        GameTooltip:Show()
    end)
    local function hideOutlierTooltip(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    showOutliers:SetScript("OnLeave", hideOutlierTooltip)
    showOutliers:SetScript("OnHide", hideOutlierTooltip)

    local resultPanel = catalog.Results
    resultPanel:SetSize(catalogWidth, bodyHeight - resultsTop)
    local resultBody, resultScroll, resultWidth, resultTitle =
        Widgets.bindPanel(resultPanel, catalogWidth, "SEARCH RESULTS")
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
    local nextPage, previousPage = resultPanel.NextPage, resultPanel.PreviousPage
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
    local resultRows = {}
    local resultMessage = label(resultBody, "GameFontHighlightSmall", colors.muted, 2, 4, resultWidth - 4,
        "Search by name or quest ID.")
    resetScroll(resultScroll, resultBody, 32, 0)

    local page = catalog

    function page:SetBrowseMode(enabled, kind)
        browsing = enabled
        search:ClearFocus()
        search:SetShown(not enabled)
        find:SetShown(not enabled)
        hint:SetShown(not enabled and search:GetText() == "")
        local classes = enabled and kind == "classes"
        categoryMenu:SetShown(classes)
        categoryHint:SetShown(enabled and not classes)
        hideCompleted:SetShown(enabled)
        showCompleted:SetShown(enabled)
        showOutliers:SetShown(enabled and not classes)
        resultTitle:SetText(enabled and "BROWSE QUESTS" or "SEARCH RESULTS")
        zoneTitle:SetText(enabled and "Type / Progress" or "Zone")
        statusTitle:SetText(enabled and "Status" or "Quest log")
        if not enabled and catalog:IsShown() then search:SetFocus() end
    end

    function page:SetCompletedFilter(filter)
        completedOnly = filter == "completed"
        hideCompleted:SetChecked(filter == "incomplete")
        showCompleted:SetText(completedOnly and "Show all" or "Show completed")
    end

    function page:SetShowOutliers(shown)
        showOutliers:SetChecked(shown == true)
    end

    function page:SetBrowseCategories(options, prompt)
        setupCategoryMenu(categoryMenu, options, prompt, callbacks.browseCategory, callbacks.selectBrowseCategory)
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

    function page:ShowResults(results, message, offset)
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

    function page:ShowBrowse(entries, message, offset, pageNumber, pageCount)
        setPageControls(pageNumber, pageCount)
        local y = startResults(message)
        for index, entry in ipairs(entries) do
            y = showResultRow(index, y, entry)
        end
        resetScroll(resultScroll, resultBody, y, offset or 0)
    end

    function page:Resize(width, height)
        local offset = resultScroll:GetVerticalScroll()
        catalog:SetSize(width, height)
        resultPanel:SetSize(width, height - resultsTop)
        local newWidth = width - panelInset
        if resultWidth == newWidth then
            updateScroll(resultScroll, offset)
            return
        end
        resultWidth = newWidth
        resultBody:SetWidth(resultWidth)
        resultMessage:SetWidth(resultWidth - 4)
        layoutResultHeadings()
        local y = resultMessage:IsShown() and resultMessage:GetStringHeight() + 12 or 0
        for _, row in ipairs(resultRows) do
            if not row:IsShown() then break end
            y = layoutResultRow(row, y)
        end
        resetScroll(resultScroll, resultBody, y, offset)
    end

    function page:UpdateVisibility(shown, scoped)
        catalog:SetShown(shown)
        catalogTitle:SetShown(not scoped)
    end

    function page:UpdateFocus(windowShown)
        if windowShown and catalog:IsShown() and not browsing then
            search:SetFocus()
        else
            search:ClearFocus()
        end
    end

    function page:Offset()
        return resultScroll:GetVerticalScroll()
    end
end
