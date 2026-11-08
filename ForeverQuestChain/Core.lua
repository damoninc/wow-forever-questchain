local _, ns = ...

local source, startupError = ns.QuestData.New(LibQuestieDB)
SLASH_FOREVERQUESTCHAIN1 = "/questchain"
if not source then
    SlashCmdList.FOREVERQUESTCHAIN = function()
        print("QuestChain: " .. startupError)
    end
    return
end

local model = ns.Chain.New(source)
local window, view, selectedId
local browseIndex, browseBuilding, browsing
local browse = { kind = "zones", page = 1, offset = 0, collapsed = {} }
local searchResults, searchMessage, searchOffset = {}, "Search by name or quest ID.", 0
local player = {
    level = 0,
    isActive = C_QuestLog.IsOnQuest,
    isReady = C_QuestLog.ReadyForTurnIn,
    isCompleted = C_QuestLog.IsQuestFlaggedCompleted,
}

local function known(value)
    return { state = "known", value = value }
end

local function unavailable()
    return { state = "unavailable" }
end

local function amount(value, rewardsReady)
    if type(value) == "number" and (value > 0 or (value == 0 and rewardsReady)) then
        return known(value)
    end
    return unavailable()
end

local function readItems(id, count, getter, rewardsReady)
    if type(count) ~= "number" or count < 0 or (count == 0 and not rewardsReady) then
        return unavailable()
    end
    local items = {}
    for index = 1, count do
        local name, icon, quantity, _, _, itemId = getter(index, id)
        if not itemId or itemId <= 0 then
            return unavailable()
        end
        if not name or name == "" then
            name = nil
            C_Item.RequestLoadItemDataByID(itemId)
        end
        items[index] = { id = itemId, name = name, icon = icon, quantity = quantity or 1 }
    end
    return known(items)
end

local function readRewards(id, loadSucceeded)
    local rewardsReady = type(HaveQuestRewardData) == "function" and HaveQuestRewardData(id) == true
    if not rewardsReady and not loadSucceeded then
        return nil
    end
    return {
        xp = amount(GetQuestLogRewardXP(id), rewardsReady),
        copper = amount(GetQuestLogRewardMoney(id), rewardsReady),
        guaranteed = readItems(id, GetNumQuestLogRewards(id), GetQuestLogRewardInfo, rewardsReady),
        choices = readItems(id, GetNumQuestLogChoices(id), GetQuestLogChoiceInfo, rewardsReady),
    }
end

local function requirementText(quest)
    local lines = {}
    local _, reason = model:Status(quest.id, player, view)
    if reason then
        lines[#lines + 1] = reason
    end
    if quest.minLevel and player.level >= quest.minLevel then
        lines[#lines + 1] = "Minimum level " .. quest.minLevel
    end
    local function questName(id)
        local prerequisite = model:GetQuest(id)
        return prerequisite and prerequisite.title or ("Quest #" .. id)
    end
    local function addGroup(ids, heading, allowSubstitutes)
        if #ids == 0 then
            return
        end
        local names = {}
        for _, id in ipairs(ids) do
            local name = questName(math.abs(id))
            local prerequisite = allowSubstitutes and id > 0 and model:GetQuest(id)
            if prerequisite and #prerequisite.exclusiveTo > 0 then
                local options = { name }
                for _, alternative in ipairs(prerequisite.exclusiveTo) do
                    options[#options + 1] = questName(alternative)
                end
                name = "(" .. table.concat(options, " or ") .. ")"
            end
            names[#names + 1] = name
        end
        lines[#lines + 1] = heading .. "  /  " .. table.concat(names, ", ")
    end
    if view.uncertainIds[quest.id] or (#quest.allOf > 0 and #quest.anyOf > 0) then
        lines[#lines + 1] = "Some requirements are unclear."
    end
    addGroup(quest.allOf, "All required", true)
    addGroup(quest.anyOf, "Any one required")
    return #lines > 0 and table.concat(lines, "\n") or nil
end

local function showDetails(id, rewardView)
    if window and id == selectedId then
        local quest = model:GetQuest(id)
        window:ShowDetails(quest, rewardView, requirementText(quest))
    end
end

local rewards = ns.Rewards.New({
    request = C_QuestLog.RequestLoadQuestByID,
    after = C_Timer.After,
    read = readRewards,
}, showDetails)

local function refreshChain(scrollToId, newLevel)
    if not view then
        return
    end
    player.level = newLevel or UnitLevel("player")
    local statuses = {}
    for _, quest in ipairs(view.quests) do
        local status, reason = model:Status(quest.id, player, view)
        statuses[quest.id] = { status = status, reason = reason }
    end
    window:ShowChain(view, selectedId, statuses, scrollToId)
end

local function selectStep(id, scrollToId)
    selectedId = id
    window:SetCatalogOpen(false)
    refreshChain(scrollToId)
    showDetails(id, rewards:Select(id))
end

local function openQuest(id, destination)
    local nextView = model:Build(id, nil, destination)
    if nextView then
        view = nextView
        selectStep(id, id)
    end
end

local function search(query)
    local results = model:Search(query)
    local message
    if #results == 0 then
        message = query:match("^%s*$") and "Enter a quest name or ID." or "No matching quests."
    end
    searchResults, searchMessage = results, message
    window:ShowResults(results, message)
    if #results == 1 then
        openQuest(results[1].id)
    end
end

local browseKinds = {
    { key = "zones", name = "Zones" },
    { key = "dungeons", name = "Dungeons" },
    { key = "classes", name = "Classes" },
}
local browsePrompts = { zones = "Choose a zone", dungeons = "Choose a dungeon", classes = "Choose a class" }

local function updateBrowseCategories()
    local options = {}
    if browseIndex then
        local shortcutKey, shortcutLabel
        if browse.kind == "zones" then
            local zone = browseIndex:MatchZone(C_Map.GetBestMapForUnit("player"))
            shortcutKey, shortcutLabel = zone and zone.key, "Current Zone"
        elseif browse.kind == "classes" then
            local _, token = UnitClass("player")
            shortcutKey, shortcutLabel = token, "My Class"
        end
        for _, category in ipairs(browseIndex:Categories(browse.kind)) do
            if category.key == shortcutKey then
                table.insert(options, 1, { key = category.key, name = category.name .. " (" .. shortcutLabel .. ")" })
            else
                options[#options + 1] = category
            end
        end
    end
    window:SetBrowseCategories(options, browsePrompts[browse.kind])
end

local function progress(id)
    if player.isActive(id) then
        return player.isReady(id) and "Ready to turn in" or "In progress"
    end
    return player.isCompleted(id) and "Completed" or "Unstarted"
end

local function showBrowse(offset)
    local entries = {}
    local message, pageNumber, pageCount
    if not browseIndex then
        message = browseBuilding and "Loading categories..." or "Quest categories unavailable."
    elseif not browse.category then
        message = "Pick a category to see its quests and chains."
    else
        local rows = browseIndex:Rows(browse.kind, browse.category, browse.collapsed, function(id)
            return browse.hideCompleted and player.isCompleted(id) and not player.isActive(id)
        end)
        local page
        page, pageNumber, pageCount = ns.Browse.Page(rows, browse.page)
        browse.page = pageNumber
        if #rows == 0 then
            message = "No matching quests."
        end
        for _, row in ipairs(page) do
            local group, step = row.group, row.step
            if step then
                local quest = step.quest
                entries[#entries + 1] = {
                    title = quest.title, indent = not group.standalone,
                    id = quest.id, level = quest.level, detail = progress(quest.id),
                    action = function() openQuest(quest.id, step.destination) end,
                }
            else
                local collapsed = browse.collapsed[group.key]
                entries[#entries + 1] = {
                    title = (collapsed and "+ " or "- ") .. group.title, heading = true,
                    action = function()
                        browse.collapsed[group.key] = not collapsed
                        showBrowse(window:ResultOffset())
                    end,
                }
            end
        end
    end
    window:ShowBrowse(entries, message, offset, pageNumber, pageCount)
end

local function setBrowseMode(enabled)
    if browsing then
        browse.offset = window:ResultOffset()
    else
        searchOffset = window:ResultOffset()
    end
    browsing = enabled
    window:SetBrowseMode(enabled)
    if not enabled then
        window:ShowResults(searchResults, searchMessage, searchOffset)
        return
    end
    if not browseIndex and not browseBuilding then
        browseBuilding = true
        local work = coroutine.create(function()
            return ns.Browse.Build(model, source, coroutine.yield)
        end)
        local function resume()
            local ok, result = coroutine.resume(work)
            if not ok or coroutine.status(work) == "dead" then
                browseBuilding = false
                if ok then
                    browseIndex = result
                else
                    print("QuestChain Browse: " .. tostring(result))
                end
                if browsing then
                    updateBrowseCategories()
                    showBrowse(window:ResultOffset())
                end
            else
                C_Timer.After(0, resume)
            end
        end
        C_Timer.After(0, resume)
    end
    updateBrowseCategories()
    showBrowse(browse.offset)
end

SlashCmdList.FOREVERQUESTCHAIN = function()
    if not window then
        window = ns.Window.New({
            search = search, openQuest = openQuest, selectStep = selectStep, setBrowseMode = setBrowseMode,
            browseKinds = browseKinds,
            browseKind = function() return browse.kind end,
            browseCategory = function() return browse.category end,
            selectBrowseKind = function(key)
                if browse.kind ~= key then
                    browse.kind, browse.category, browse.page = key, nil, 1
                    updateBrowseCategories()
                    showBrowse(0)
                end
            end,
            selectBrowseCategory = function(key)
                if browse.category ~= key then
                    browse.category, browse.page = key, 1
                    showBrowse(0)
                end
            end,
            hideCompleted = function(checked)
                browse.hideCompleted = checked
                showBrowse(0)
            end,
            browsePage = function(step)
                browse.page = browse.page + step
                showBrowse(0)
            end,
        })
    end
    window:Toggle()
end

local function itemInRewards(rewardView, itemId)
    for _, field in ipairs({ rewardView.guaranteed, rewardView.choices }) do
        for _, item in ipairs(field.value or {}) do
            if item.id == itemId then
                return true
            end
        end
    end
    return false
end

local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_DATA_LOAD_RESULT")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, event, id, success)
    if event == "QUEST_DATA_LOAD_RESULT" then
        rewards:OnQuestDataLoaded(id, success)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if success and selectedId then
            local rewardView = rewards:Get(selectedId)
            if itemInRewards(rewardView, id) then
                showDetails(selectedId, rewardView)
            end
        end
    elseif event == "PLAYER_LEVEL_UP" then
        refreshChain(nil, id)
        rewards:Invalidate()
    elseif event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" then
        refreshChain()
        rewards:Invalidate(id)
    elseif selectedId then
        refreshChain()
        showDetails(selectedId, rewards:Get(selectedId))
    end
    if browsing and browseIndex and browse.category
        and (event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN") then
        showBrowse(window:ResultOffset())
    end
end)
