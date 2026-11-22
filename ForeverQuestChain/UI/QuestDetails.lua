local _, ns = ...

local QuestDetails = {}
ns.QuestDetails = QuestDetails

local Widgets = ns.Widgets
local colors = Widgets.colors
local itemFallbackIcon = Widgets.itemFallbackIcon
local fill = Widgets.fill
local font = Widgets.font
local label = Widgets.label
local itemName = Widgets.itemName
local makeControl = Widgets.makeControl
local hideAll = Widgets.hideAll
local resetScroll = Widgets.resetScroll
local showTooltip = Widgets.showTooltip
local tryLinkReward = Widgets.tryLinkReward
local hideOwnedTooltip = Widgets.hideOwnedTooltip

local function questAtlas(parent, layer, atlas)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetAtlas(atlas, true)
    return texture
end

function QuestDetails.New(parent, top, width, height)
    local frame = CreateFrame("Frame", nil, parent, "ForeverQuestChainQuestDetailsTemplate")
    frame:SetPoint("TOPRIGHT", -14, -top)
    frame:SetSize(width, height)
    local paper = frame.Parchment
    frame.BackButton:SetText(BACK or "Back")

    local contentWidth = width - 26
    local scroll = frame.DetailsScroll
    scroll:EnableMouseWheel(true)
    local body = scroll:GetScrollChild()
    body:SetWidth(contentWidth)

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

    local page = { frame = frame }

    function page:Render(quest, rewards, requirement, log)
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
                row:SetScript("OnClick", function(button) if button.reward then tryLinkReward(button) end end)
                row:SetScript("OnEnter", function(button) if button.reward then showTooltip(button) end end)
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

    function page:Resize(newHeight)
        frame:SetHeight(newHeight)
    end

    return page
end
