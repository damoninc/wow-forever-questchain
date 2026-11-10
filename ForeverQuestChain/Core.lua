local _, ns = ...

local source, startupError = ns.QuestData.New(LibQuestieDB)
SLASH_FOREVERQUESTCHAIN1 = "/questchain"
if not source then
    SlashCmdList.FOREVERQUESTCHAIN = function()
        print("QuestChain: " .. startupError)
    end
    return
end

local model = ns.Chain.New(source, function()
    local raceId = UnitRace and select(3, UnitRace("player"))
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return source.characterFilter(raceId, faction)
end)
local window, view, selectedId, chainCategory
local browseIndex, browseBuilding, browsing
local browse = { kind = "zones", page = 1, offset = 0, lastCategory = {} }
local rewardCatalog, rewardBuilding, rewardState
local searchResults, searchMessage, searchOffset = {}, "Search by name or quest ID.", 0
local player = {
    level = 0,
    isActive = C_QuestLog.IsOnQuest,
    isReady = C_QuestLog.ReadyForTurnIn,
    isCompleted = C_QuestLog.IsQuestFlaggedCompleted,
}

local function questLogStatus(id)
    return ns.Chain.QuestLogStatus(id, player)
end

local function partyOnQuest(id)
    if not C_QuestLog.IsUnitOnQuest then return end
    local members
    for index = 1, GetNumSubgroupMembers() do
        local unit = "party" .. index
        if UnitIsConnected(unit) and C_QuestLog.IsUnitOnQuest(unit, id) then
            local name, realm = UnitName(unit)
            if name then
                members = members or {}
                members[#members + 1] = realm and realm ~= "" and (name .. "-" .. realm) or name
            end
        end
    end
    return members
end

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
    window:ShowChain(view, selectedId, statuses, scrollToId, chainCategory)
end

local function selectStep(id, scrollToId)
    selectedId = id
    window:SetCatalogOpen(false)
    refreshChain(scrollToId)
    showDetails(id, rewards:Select(id))
end

local function categoryForQuest(quest)
    local classes = source.classes(quest.zoneOrSort, quest.classMask)
    if #classes == 1 then return { kind = "classes", category = classes[1] } end
    local dungeon = source.dungeon(quest.areaId)
    if dungeon then return { kind = "dungeons", category = dungeon } end
    local zones = source.pickupZones(quest.id)
    if #zones == 0 then return end
    if #zones == 1 then return { kind = "zones", category = zones[1] } end

    local byMap = {}
    for _, zone in ipairs(zones) do byMap[zone.key] = zone end
    local recorded = byMap[source.zoneMapId(quest.areaId)]
    if recorded then return { kind = "zones", category = recorded } end

    local mapId, visited = C_Map.GetBestMapForUnit("player"), {}
    while mapId and mapId > 0 and not visited[mapId] do
        local current = byMap[mapId]
        if current then return { kind = "zones", category = current } end
        visited[mapId] = true
        mapId = source.zoneParent(mapId)
    end
    return { kind = "zones" }
end

local function openQuest(id, destination, context)
    local nextView = model:Build(id, nil, destination)
    if not nextView then
        return false
    end
    view = nextView
    chainCategory = context or categoryForQuest(model:GetQuest(id))
    if chainCategory and chainCategory.category then
        browse.lastCategory[chainCategory.kind] = chainCategory.category.key
    end
    window:Show()
    selectStep(id, id)
    return true
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

local function categoryOptions(kind)
    local options = {}
    if browseIndex then
        local shortcutKey, shortcutLabel
        if kind == "zones" then
            local zone = browseIndex:MatchZone(C_Map.GetBestMapForUnit("player"))
            shortcutKey, shortcutLabel = zone and zone.key, "Current Zone"
        elseif kind == "classes" then
            local _, token = UnitClass("player")
            shortcutKey, shortcutLabel = token, "My Class"
        end
        for _, category in ipairs(browseIndex:Categories(kind)) do
            local name = category.name
            if category.key == shortcutKey then
                name = name .. " (" .. shortcutLabel .. ")"
            end
            if kind ~= "classes" and category.minLevel then
                name = name .. "  /  Lv " .. category.minLevel
                if category.maxLevel > category.minLevel then
                    name = name .. "-" .. category.maxLevel
                end
            end
            local option = { key = category.key, name = name }
            if category.key == shortcutKey then
                table.insert(options, 1, option)
            else
                options[#options + 1] = option
            end
        end
    end
    return options
end

local function updateBrowseCategories()
    window:SetBrowseCategories(categoryOptions(browse.kind), browsePrompts[browse.kind])
end

local function showBrowse(offset)
    local entries = {}
    local message, pageNumber, pageCount
    if not browseIndex then
        message = browseBuilding and "Loading categories..." or "Quest categories unavailable."
    elseif not browse.category then
        message = "Pick a category to see its quests and chains."
    else
        local filter = browse.completedFilter
        local rows = browseIndex:Rows(browse.kind, browse.category, filter, questLogStatus)
        local page
        page, pageNumber, pageCount = ns.Browse.Page(rows, browse.page)
        browse.page = pageNumber
        if #rows == 0 then
            message = filter == "completed" and "No completed quests in this category." or "No matching quests."
        end
        for _, row in ipairs(page) do
            local group, step = row.group, row.step
            local quest = step.quest
            local detail = group.standalone and (browse.kind == "dungeons" and "Dungeon quest" or "Quest")
                or ("Chain  /  %d/%d complete"):format(row.completed, #group.steps)
            entries[#entries + 1] = {
                title = group.title, id = group.standalone and quest.id or nil,
                level = group.level, detail = detail, logStatus = row.status,
                action = function()
                    openQuest(quest.id, step.destination, {
                        kind = browse.kind, category = browseIndex:Category(browse.kind, browse.category),
                    })
                end,
            }
        end
    end
    window:ShowBrowse(entries, message, offset, pageNumber, pageCount)
end

local function showRewardCatalog(offset)
    local entries, selected, message = {}, nil, nil
    if rewardBuilding or browseBuilding then
        message = "Loading quest rewards..."
    elseif not rewardCatalog or not browseIndex then
        message = "Quest rewards unavailable from QuestieDB."
    elseif not rewardState.category then
        message = "Choose a zone or dungeon to see its quest rewards."
    else
        entries = rewardCatalog:Search(browseIndex, rewardState.kind, rewardState.category, rewardState.query)
        for _, entry in ipairs(entries) do
            if entry.item.id == rewardState.selectedId then
                selected = entry
                break
            end
        end
        selected = selected or entries[1]
        rewardState.selectedId = selected and selected.item.id
        if not selected then message = "No matching quest rewards." end
    end
    window:ShowRewardItems(entries, selected, message, offset)
end

local function updateRewardCategories()
    if browseIndex and rewardState.useCurrentZone then
        local zone = browseIndex:MatchZone(C_Map.GetBestMapForUnit("player"))
        rewardState.category = zone and zone.key
        rewardState.useCurrentZone = nil
    end
    local kind = rewardState.kind
    window:SetRewardCategories(categoryOptions(kind), browsePrompts[kind])
end

local function buildIndex(build, finish)
    local work = coroutine.create(function() return build(coroutine.yield) end)
    local function resume()
        local ok, result = coroutine.resume(work)
        if not ok or coroutine.status(work) == "dead" then
            finish(ok, result)
        else
            C_Timer.After(0, resume)
        end
    end
    C_Timer.After(0, resume)
end

local function loadBrowseIndex()
    if browseIndex or browseBuilding then return end
    browseBuilding = true
    buildIndex(function(yieldWork)
        return ns.Browse.Build(model, source, yieldWork)
    end, function(ok, result)
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
        if rewardState then
            updateRewardCategories()
            showRewardCatalog(window:RewardOffset())
        end
    end)
end

local function openRewardCatalog()
    if not rewardState then
        local kind = browse.kind == "dungeons" and "dungeons" or "zones"
        local category = browse.kind == kind and browse.category or nil
        rewardState = { kind = kind, category = category, query = "", useCurrentZone = not category and kind == "zones" }
        updateRewardCategories()
    end
    loadBrowseIndex()
    if not rewardCatalog and not rewardBuilding then
        rewardBuilding = true
        buildIndex(function(yieldWork)
            return ns.RewardCatalog.Build(source, yieldWork)
        end, function(ok, result)
            rewardBuilding = false
            if ok then
                rewardCatalog = result
            else
                print("QuestChain Rewards: " .. tostring(result))
            end
            showRewardCatalog(window:RewardOffset())
        end)
    end
    showRewardCatalog(window:RewardOffset())
end

local function setBrowseMode(enabled, kind, category)
    if browsing then
        browse.offset = window:ResultOffset()
    else
        searchOffset = window:ResultOffset()
    end
    if kind and (kind ~= browse.kind or category ~= browse.category) then
        browse.kind, browse.category, browse.page, browse.offset = kind, category, 1, 0
    end
    if kind and category then browse.lastCategory[kind] = category end
    browsing = enabled
    window:SetBrowseMode(enabled)
    if not enabled then
        window:ShowResults(searchResults, searchMessage, searchOffset)
        return
    end
    loadBrowseIndex()
    updateBrowseCategories()
    showBrowse(browse.offset)
end

local function getWindow()
    if not window then
        window = ns.Window.New({
            search = search, openQuest = openQuest, selectStep = selectStep, setBrowseMode = setBrowseMode,
            openLinkedQuest = function(id) openQuest(id, nil, chainCategory) end,
            openBrowseCategory = function(kind, category)
                setBrowseMode(true, kind, category)
                window:SetCatalogOpen(true)
            end,
            questLogStatus = questLogStatus,
            partyOnQuest = partyOnQuest,
            browseKinds = browseKinds,
            browseKind = function() return browse.kind end,
            browseCategory = function() return browse.category end,
            selectBrowseKind = function(key)
                if browse.kind ~= key then
                    browse.kind, browse.category, browse.page = key, browse.lastCategory[key], 1
                    updateBrowseCategories()
                    showBrowse(0)
                end
            end,
            selectBrowseCategory = function(key)
                if browse.category ~= key then
                    browse.lastCategory[browse.kind] = key
                    browse.category, browse.page = key, 1
                    showBrowse(0)
                end
            end,
            setCompletedFilter = function(filter)
                browse.completedFilter, browse.page = filter, 1
                window:SetCompletedFilter(filter)
                showBrowse(0)
            end,
            browsePage = function(step)
                browse.page = browse.page + step
                showBrowse(0)
            end,
            rewardPage = {
                open = openRewardCatalog,
                openQuest = function(id, destination)
                    openQuest(id, destination, {
                        kind = rewardState.kind,
                        category = browseIndex:Category(rewardState.kind, rewardState.category),
                    })
                end,
                kinds = { browseKinds[1], browseKinds[2] },
                kind = function() return rewardState and rewardState.kind or "zones" end,
                category = function() return rewardState.category end,
                selectKind = function(kind)
                    if rewardState.kind ~= kind then
                        rewardState.kind, rewardState.category, rewardState.useCurrentZone = kind, nil, nil
                        updateRewardCategories()
                        showRewardCatalog(0)
                    end
                end,
                selectCategory = function(key)
                    rewardState.category = key
                    showRewardCatalog(0)
                end,
                search = function(query)
                    rewardState.query = query
                    showRewardCatalog(0)
                end,
                selectItem = function(id)
                    rewardState.selectedId = id
                    showRewardCatalog(window:RewardOffset())
                end,
            },
        })
    end
    return window
end

SlashCmdList.FOREVERQUESTCHAIN = function()
    getWindow():Toggle()
end

local questLogAction = "Open in QuestChain"

local function openQuestFromLog(id)
    getWindow()
    if not openQuest(id) then
        print("QuestChain: Quest #" .. id .. " is unavailable for this character.")
    end
end

local function addQuestLogAction(owner, menu)
    local id = owner and owner.questID
    -- The gamepad quest details menu is owned by the map, rather than the quest row.
    if not id and owner == WorldMapFrame and QuestMapFrame and QuestMapFrame.DetailsFrame then
        id = QuestMapFrame.DetailsFrame.questID
    end
    if type(id) ~= "number" or id <= 0 then
        return
    end
    menu:CreateButton(questLogAction, function() openQuestFromLog(id) end)
end

if Menu and Menu.ModifyMenu then
    Menu.ModifyMenu("MENU_QUEST_MAP_LOG_TITLE", addQuestLogAction)
    Menu.ModifyMenu("MENU_QUEST_LOG_POPUP_DETAIL_FRAME", addQuestLogAction)
end

local questDetailsButton

local function showQuestDetailsButton()
    local details = QuestMapFrame and QuestMapFrame.DetailsFrame
    local header = details and details.BackFrame
    if not header or not header.BackButton then
        return
    end
    if not questDetailsButton then
        local button = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
        button:SetPoint("LEFT", header.BackButton, "RIGHT", 6, 0)
        button:SetScript("OnClick", function()
            if details.questID then openQuestFromLog(details.questID) end
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(questLogAction)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        questDetailsButton = button
    end
    local notice = header.AccountCompletedNotice
    local compact = notice and notice:IsShown()
    questDetailsButton:SetSize(compact and 36 or 126, 22)
    questDetailsButton:SetText(compact and "QC" or questLogAction)
end

if type(QuestMapFrame_ShowQuestDetails) == "function" then
    hooksecurefunc("QuestMapFrame_ShowQuestDetails", showQuestDetailsButton)
    if QuestMapFrame and QuestMapFrame.DetailsFrame and QuestMapFrame.DetailsFrame:IsShown() then
        showQuestDetailsButton()
    end
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
events:RegisterEvent("QUEST_REMOVED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
local partyEvents = {
    GROUP_ROSTER_UPDATE = true,
    UNIT_QUEST_LOG_CHANGED = true,
    PARTY_MEMBER_ENABLE = true,
    PARTY_MEMBER_DISABLE = true,
}
for event in pairs(partyEvents) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, id, success)
    if partyEvents[event] then
        if not window or (event == "UNIT_QUEST_LOG_CHANGED" and not (id and id:match("^party%d+$"))) then
            return
        end
        refreshChain()
        if not browsing and #searchResults > 0 then
            window:ShowResults(searchResults, searchMessage, window:ResultOffset())
        end
        return
    elseif event == "QUEST_DATA_LOAD_RESULT" then
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
    if not window then return end
    if event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED"
        or event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED" then
        if browsing and browseIndex and browse.category then
            showBrowse(window:ResultOffset())
        elseif not browsing and #searchResults > 0 then
            window:ShowResults(searchResults, searchMessage, window:ResultOffset())
        end
    end
end)
