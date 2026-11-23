local _, ns = ...

local JournalController = {}
ns.JournalController = JournalController

local LocationQuestCatalog = ns.LocationQuestCatalog

---@class JournalDependencies
---@field questRepository QuestRepository
---@field characterState CharacterQuestState
---@field mapMetadata MapMetadata
---@field questSearch QuestSearch
---@field questChain QuestChain
---@field questProgress QuestProgress
---@field locationContext QuestLocationContext
---@field activeChains ActiveChainsQuery
---@field describeRequirements fun(quest: QuestSummary, view: QuestChainView): QuestRequirementDescription
---@field newRewardLoader fun(onUpdate: fun(questId: integer, view: QuestRewardView)): QuestRewardLoader
---@field buildLocationCatalog fun(yieldWork: fun()): LocationQuestCatalog
---@field buildRewardCatalog fun(yieldWork: fun()): LocationRewardCatalog?
---@field schedule fun(delaySeconds: number, callback: function)
---@field createWindow fun(callbacks: table): table

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

---@param dependencies JournalDependencies
function JournalController.New(dependencies)
    local quests = dependencies.questRepository
    local character = dependencies.characterState
    local mapMetadata = dependencies.mapMetadata
    local questProgress = dependencies.questProgress
    local schedule = dependencies.schedule
    local window, view, selectedId, chainCategory
    local browseIndex, browseBuilding, browsing
    local browse = { kind = "zones", page = 1, offset = 0 }
    local browseStates, rewardStates = {}, {}
    local rewardCatalog, rewardBuilding, rewardState
    local searchResults, searchMessage, searchOffset = {}, "Search by name or quest ID.", 0
    local playerLevel = 0

    local function questLogStatus(id)
        return questProgress:GetLogStatus(id)
    end

    local function questTitle(id)
        local prerequisite = quests:GetSummary(id)
        return prerequisite and prerequisite.title or ("Quest #" .. id)
    end

    local function requirementText(quest)
        local _, reason = questProgress:GetStatus(quest.id, view, playerLevel)
        local minimum = quest.minLevel
        local satisfiedMinimum = minimum and playerLevel and playerLevel >= minimum and minimum or nil
        return ns.QuestRequirementsText.Format(
            dependencies.describeRequirements(quest, view), reason, satisfiedMinimum, questTitle)
    end

    local function showDetails(id, rewardView)
        if window and id == selectedId then
            local quest = quests:GetDetails(id)
            window.questDetails:Render(quest, rewardView, requirementText(quest), character:GetLogDetails(id))
        end
    end

    local rewards = dependencies.newRewardLoader(showDetails)

    local function refreshChain(scrollToId, newLevel)
        if not view then
            return
        end
        playerLevel = newLevel or character:GetLevel()
        local statuses = {}
        for _, quest in ipairs(view.quests) do
            local status, reason = questProgress:GetStatus(quest.id, view, playerLevel)
            statuses[quest.id] = { status = status, reason = reason }
        end
        window.timeline:Render(view, selectedId, statuses, scrollToId, chainCategory)
    end

    local function selectStep(id, scrollToId)
        selectedId = id
        window:OpenQuestPage()
        refreshChain(scrollToId)
        showDetails(id, rewards:Select(id))
    end

    local function openQuest(id, destination, context)
        local nextView = dependencies.questChain:Build(id, nil, destination)
        if not nextView then
            return false
        end
        view = nextView
        chainCategory = context or dependencies.locationContext:ForQuest(id)
        window:ShowJournal()
        selectStep(id, id)
        return true
    end

    local function showActiveChains()
        if not browseIndex then
            window.activeChains:Render({}, browseBuilding and "Loading active chains..." or "Quest chains unavailable.")
            return
        end
        local groups, count = dependencies.activeChains:Run(browseIndex)
        window.activeChains:Render(groups, nil, count)
    end

    local function search(query)
        local results = dependencies.questSearch:Search(query)
        local message
        if #results == 0 then
            message = query:match("^%s*$") and "Enter a quest name or ID." or "No matching quests."
        end
        searchResults, searchMessage = results, message
        window.questList:ShowResults(results, message)
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
                local zone = browseIndex:MatchZone(mapMetadata:GetPlayerMapId())
                shortcutKey, shortcutLabel = zone and zone.key, "Current Zone"
            elseif kind == "classes" then
                local token = character:GetIdentity().classToken
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
        window.questList:SetBrowseCategories(categoryOptions(browse.kind), browsePrompts[browse.kind])
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
            local rows = browseIndex:Rows(browse.kind, browse.category, filter, questLogStatus, browse.showOutliers)
            local page
            page, pageNumber, pageCount = LocationQuestCatalog.Page(rows, browse.page)
            browse.page = pageNumber
            if #rows == 0 then
                message = filter == "completed" and "No completed quests in this category." or "No matching quests."
            end
            for _, row in ipairs(page) do
                local group, step = row.group, row.step
                local quest = step.quest
                local detail = group.standalone and (browse.kind == "dungeons" and "Dungeon quest" or "Quest")
                    or (row.status == "completed" and "Chain")
                    or ("Chain  /  %d/%d complete"):format(row.completed, #group.steps)
                entries[#entries + 1] = {
                    title = group.title, id = group.standalone and quest.id or nil,
                    level = row.level, detail = detail, logStatus = row.status,
                    action = function()
                        openQuest(quest.id, step.destination, {
                            kind = browse.kind, category = browseIndex:Category(browse.kind, browse.category),
                        })
                    end,
                }
            end
        end
        window.questList:ShowBrowse(entries, message, offset, pageNumber, pageCount)
    end

    local function showRewardCatalog(offset, sourceOffset)
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
        window.rewards:Render(entries, selected, message, offset, sourceOffset)
    end

    local function showLocationCatalog(kind)
        local entries = browseIndex and browseIndex:Categories(kind) or {}
        local message
        if not browseIndex then
            message = browseBuilding and "Loading locations..." or "Quest locations unavailable."
        end
        window.locations:Render(kind, entries, message)
    end

    local function buildIndex(build, finish)
        local work = coroutine.create(function() return build(coroutine.yield) end)
        local function resume()
            local ok, result = coroutine.resume(work)
            if not ok or coroutine.status(work) == "dead" then
                finish(ok, result)
            else
                schedule(0, resume)
            end
        end
        schedule(0, resume)
    end

    local function loadBrowseIndex()
        if browseIndex or browseBuilding then return end
        browseBuilding = true
        buildIndex(function(yieldWork)
            return dependencies.buildLocationCatalog(yieldWork)
        end, function(ok, result)
            browseBuilding = false
            if ok then
                browseIndex = result
            else
                print("QuestChain Browse: " .. tostring(result))
            end
            if not window then return end
            if browsing then
                updateBrowseCategories()
                showBrowse(window.questList:Offset())
            end
            if rewardState then
                showRewardCatalog(window.rewards:Offset())
            end
            local route = window:Route()
            if route.page == "locations" then showLocationCatalog(route.kind) end
            window:RefreshNavigation()
            if window:IsActiveChainsOpen() then showActiveChains() end
        end)
    end

    local function openActiveChains()
        loadBrowseIndex()
        showActiveChains()
    end

    local function openRewardCatalog(kind, category)
        if rewardState then
            rewardState.offset = window.rewards:Offset()
            rewardState.sourceOffset = window.rewards:SourceOffset()
        end
        local identity = kind .. ":" .. category
        rewardState = rewardStates[identity]
        if not rewardState then
            rewardState = { kind = kind, category = category, query = "", offset = 0, sourceOffset = 0 }
            rewardStates[identity] = rewardState
        end
        window.rewards:SetQuery(rewardState.query)
        loadBrowseIndex()
        if not rewardCatalog and not rewardBuilding then
            rewardBuilding = true
            buildIndex(function(yieldWork)
                return dependencies.buildRewardCatalog(yieldWork)
            end, function(ok, result)
                rewardBuilding = false
                if ok then
                    rewardCatalog = result
                else
                    print("QuestChain Rewards: " .. tostring(result))
                end
                showRewardCatalog(window.rewards:Offset())
            end)
        end
        showRewardCatalog(rewardState.offset, rewardState.sourceOffset)
    end

    local function setBrowseMode(enabled, kind, category)
        if browsing then
            browse.offset = window.questList:Offset()
        else
            searchOffset = window.questList:Offset()
        end
        if kind and kind ~= browse.kind then
            browseStates[browse.kind] = browse
            browse = browseStates[kind] or { kind = kind, page = 1, offset = 0 }
            browseStates[kind] = browse
        end
        if kind and category ~= browse.category then
            browse.category, browse.page, browse.offset = category, 1, 0
        end
        browsing = enabled
        window.questList:SetBrowseMode(enabled, kind)
        if not enabled then
            window.questList:ShowResults(searchResults, searchMessage, searchOffset)
            return
        end
        loadBrowseIndex()
        updateBrowseCategories()
        window.questList:SetCompletedFilter(browse.completedFilter)
        window.questList:SetShowOutliers(browse.showOutliers)
        showBrowse(browse.offset)
    end

    local function openJournalRoute(route)
        if route.page == "locations" then
            loadBrowseIndex()
            showLocationCatalog(route.kind)
        elseif route.page == "search" then
            setBrowseMode(false)
        elseif route.page == "quests" then
            setBrowseMode(true, route.kind, route.key)
        elseif route.page == "rewards" then
            openRewardCatalog(route.kind, route.key)
        elseif route.page == "activeChains" then
            openActiveChains()
        end
    end

    local function getWindow()
        if not window then
            window = dependencies.createWindow({
                search = search, openQuest = openQuest, selectStep = selectStep,
                openJournalRoute = openJournalRoute,
                categoryName = function(kind, key)
                    local category = browseIndex and browseIndex:Category(kind, key)
                    return category and category.name
                end,
                currentZone = function()
                    return browseIndex and browseIndex:MatchZone(mapMetadata:GetPlayerMapId())
                end,
                playerClass = character:GetIdentity().classToken,
                openLinkedQuest = function(id) openQuest(id, nil, chainCategory) end,
                openBrowseCategory = function(kind, category)
                    if category then window:OpenCategory(kind, category) else window:OpenLocations(kind) end
                end,
                questLogStatus = questLogStatus,
                openActiveChains = openActiveChains,
                partyOnQuest = function(id) return character:GetPartyMembersOnQuest(id) end,
                playerLevel = function() return character:GetLevel() end,
                browseKinds = browseKinds,
                browseCategory = function() return browse.category end,
                selectBrowseCategory = function(key)
                    if browse.category ~= key then
                        window:OpenCategory(browse.kind, key)
                    end
                end,
                setCompletedFilter = function(filter)
                    browse.completedFilter, browse.page = filter, 1
                    window.questList:SetCompletedFilter(filter)
                    showBrowse(0)
                end,
                setShowOutliers = function(shown)
                    browse.showOutliers, browse.page = shown, 1
                    showBrowse(0)
                end,
                browsePage = function(step)
                    browse.page = browse.page + step
                    showBrowse(0)
                end,
                rewardPage = {
                    openQuest = function(id, destination)
                        openQuest(id, destination, {
                            kind = rewardState.kind,
                            category = browseIndex:Category(rewardState.kind, rewardState.category),
                        })
                    end,
                    search = function(query)
                        rewardState.query = query
                        showRewardCatalog(0)
                    end,
                    selectItem = function(id)
                        rewardState.selectedId = id
                        showRewardCatalog(window.rewards:Offset())
                    end,
                },
            })
        end
        return window
    end

    local controller = {}

    function controller:OnLogin()
        loadBrowseIndex()
    end

    function controller:Toggle()
        getWindow():Toggle()
    end

    function controller:OpenFromQuestLog(id)
        getWindow()
        if not openQuest(id) then
            print("QuestChain: Quest #" .. id .. " is unavailable for this character.")
        end
    end

    local function refreshSearchResults()
        if not browsing and #searchResults > 0 then
            window.questList:ShowResults(searchResults, searchMessage, window.questList:Offset())
        end
    end

    local function refreshQuestLists()
        if not window then return end
        if window:IsActiveChainsOpen() then showActiveChains() end
        if browsing and browseIndex and browse.category then
            showBrowse(window.questList:Offset())
        else
            refreshSearchResults()
        end
    end

    function controller:OnPartyChanged()
        if not window then return end
        refreshChain()
        refreshSearchResults()
    end

    function controller:OnQuestDataLoaded(id, success)
        rewards:OnQuestDataLoaded(id, success)
    end

    function controller:OnItemDataLoaded(id, success)
        if not success or not selectedId then return end
        local rewardView = rewards:Get(selectedId)
        if itemInRewards(rewardView, id) then
            showDetails(selectedId, rewardView)
        end
    end

    function controller:OnLevelUp(level)
        refreshChain(nil, level)
        rewards:Invalidate()
    end

    function controller:OnQuestProgressChanged(id)
        refreshChain()
        rewards:Invalidate(id)
        refreshQuestLists()
    end

    function controller:OnQuestLogChanged()
        if selectedId then
            refreshChain()
            showDetails(selectedId, rewards:Get(selectedId))
        end
        refreshQuestLists()
    end

    return controller
end
