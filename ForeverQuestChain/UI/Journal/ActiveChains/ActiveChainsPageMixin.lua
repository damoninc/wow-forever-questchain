local _, ns = ...

ForeverQuestChainActiveChainsPageMixin = {}
local ActiveChainsPage = ForeverQuestChainActiveChainsPageMixin

local Widgets = ns.Widgets
local colors = Widgets.colors
local statuses = Widgets.statuses
local updateScroll = Widgets.updateScroll
local panelInset = Widgets.panelInset
local label = Widgets.label
local makeButton = Widgets.makeButton
local hideAll = Widgets.hideAll
local resetScroll = Widgets.resetScroll

function ActiveChainsPage.Initialize(frame, width, height, openQuest)
    frame:SetSize(width, height)
    local body, scroll, contentWidth, title =
        Widgets.bindPanel(frame, width, "ACTIVE CHAINS")
    local rows, headers, collapsed = {}, {}, {}
    local groups, currentMessage, chainCount = {}, nil, 0
    local notice = label(body, "GameFontHighlightSmall", colors.muted, 6, 4, contentWidth - 12, "")

    local render
    render = function()
        local offset = scroll:GetVerticalScroll()
        hideAll(rows)
        hideAll(headers)
        notice:SetText(currentMessage or "No active quest chains.")
        notice:SetShown(#groups == 0)
        title:SetText(currentMessage and "ACTIVE CHAINS" or ("ACTIVE CHAINS  /  %d"):format(chainCount))
        local y, rowIndex = 4, 0
        for index, group in ipairs(groups) do
            local header = headers[index]
            if not header then
                header = CreateFrame("Button", nil, body, "ForeverQuestChainActiveChainsHeaderTemplate")
                header:SetScript("OnClick", function(self)
                    collapsed[self.groupKey] = not collapsed[self.groupKey]
                    render()
                end)
                headers[index] = header
            end
            header.groupKey = group.key
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", 0, -y)
            header:SetSize(contentWidth, 30)
            local count = #group.rows
            local countText = count == 1 and "1 chain" or (count .. " chains")
            local kind = group.kind == "dungeons" and "Dungeon" or "Zone"
            header:SetText(group.category.name .. "  /  " .. kind .. "  /  " .. countText)
            header.toggle:SetText(collapsed[group.key] and "+" or "−")
            header:Show()
            y = y + 34
            if not collapsed[group.key] then
                for _, entry in ipairs(group.rows) do
                    rowIndex = rowIndex + 1
                    local row = rows[rowIndex]
                    if not row then
                        row = makeButton(body)
                        row.title:SetPoint("TOPRIGHT", -8, -6)
                        row.meta:SetPoint("TOPRIGHT", -8, -24)
                        row:SetScript("OnClick", function(self)
                            openQuest(self.step.quest.id, self.step.destination, self.context)
                        end)
                        rows[rowIndex] = row
                    end
                    row.step = entry.step
                    row.context = { kind = group.kind, category = group.category }
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", 12, -y)
                    row:SetSize(contentWidth - 12, 42)
                    row.title:SetText(entry.title)
                    local quest, log = entry.step.quest, entry.log
                    local status = statuses[log.status]
                    local active = entry.count == 1 and "1 active step" or (entry.count .. " active steps")
                    local level = log.level or quest.level
                    local context = (level and ("  /  Level " .. level) or "") .. (log.zone and ("  /  " .. log.zone) or "")
                    row.meta:SetText(status[1] .. "  /  " .. active .. "  /  " .. quest.title .. " (#" .. quest.id .. ")" .. context)
                    row.meta:SetTextColor(status[2], status[3], status[4])
                    row:Show()
                    y = y + 44
                end
            end
            y = y + 6
        end
        resetScroll(scroll, body, math.max(32, y), offset)
    end

    local page = frame

    function page:Render(entries, message, count)
        groups, currentMessage, chainCount = entries, message, count or 0
        render()
    end

    function page:Resize(newWidth, newHeight)
        local offset = scroll:GetVerticalScroll()
        frame:SetSize(newWidth, newHeight)
        local newContentWidth = newWidth - panelInset
        if newContentWidth ~= contentWidth then
            contentWidth = newContentWidth
            body:SetWidth(contentWidth)
            notice:SetWidth(contentWidth - 12)
            for _, row in ipairs(rows) do row:SetWidth(contentWidth - 12) end
            for _, header in ipairs(headers) do header:SetWidth(contentWidth) end
        end
        updateScroll(scroll, offset)
    end
end
