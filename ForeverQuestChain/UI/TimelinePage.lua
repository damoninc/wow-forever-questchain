local _, ns = ...

local TimelinePage = {}
ns.TimelinePage = TimelinePage

local Widgets = ns.Widgets
local colors = Widgets.colors
local statuses = Widgets.statuses
local panelInset = Widgets.panelInset
local partyLineHeight = Widgets.partyLineHeight
local font = Widgets.font
local label = Widgets.label
local panel = Widgets.panel
local makeBreadcrumb = Widgets.makeBreadcrumb
local setBreadcrumbText = Widgets.setBreadcrumbText
local makeBrowseMenu = Widgets.makeBrowseMenu
local makeTimelineButton = Widgets.makeTimelineButton
local hideAll = Widgets.hideAll
local updateScroll = Widgets.updateScroll
local resetScroll = Widgets.resetScroll
local setPartyStatus = Widgets.setPartyStatus

function TimelinePage.New(frame, sideMargin, bodyTop, initialWidth, bodyHeight, callbacks)
    local chainBody, chainScroll, chainWidth, chainPanel =
        panel(frame, sideMargin, bodyTop, initialWidth, bodyHeight, "QUEST TIMELINE")
    chainScroll:SetPoint("TOPLEFT", 10, -106)
    local chainTitle = label(chainPanel, "GameFontNormalHuge", colors.text, 12, 30, chainWidth, "")
    chainTitle:SetWordWrap(false)
    local chainContext = label(chainPanel, "GameFontHighlightSmall", colors.muted, 12, 59, chainWidth, "")
    local browseCrumb = makeBreadcrumb(chainPanel)
    setBreadcrumbText(browseCrumb, "Back")
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
    local chainRows, connectors = {}, {}
    local chainMessage = label(chainBody, "GameFontHighlightSmall", colors.muted, 2, 4, chainWidth - 4, "")
    resetScroll(chainScroll, chainBody, 32, 0)

    browseCrumb:SetScript("OnClick", callbacks.back)
    local page = { frame = chainPanel }

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
            kindCrumb:SetScript("OnClick", function() callbacks.openLocations(kind) end)
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
    function page:Render(view, selectedId, statusesById, scrollToId, context)
        lastView, lastSelected, lastStatuses, lastContext = view, selectedId, statusesById, context
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

    function page:Resize(width, height)
        local offset = chainScroll:GetVerticalScroll()
        chainPanel:SetSize(width, height)
        local newWidth = width - panelInset
        if chainWidth == newWidth then
            updateScroll(chainScroll, offset)
            return
        end
        chainWidth = newWidth
        chainTitle:SetWidth(chainWidth)
        chainContext:SetWidth(chainWidth)
        chainMessage:SetWidth(chainWidth - 4)
        if lastView then
            updateScroll(chainScroll, offset)
            self:Render(lastView, lastSelected, lastStatuses, nil, lastContext)
        else
            chainBody:SetWidth(chainWidth)
            updateScroll(chainScroll, offset)
        end
    end

    return page
end
