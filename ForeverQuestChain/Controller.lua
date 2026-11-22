local _, ns = ...

local Controller = {}
ns.Controller = Controller

local ForeverQuests = ns.ForeverQuests

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

function Controller.New(source)
    local model = ns.Chain.New(source, function() return ForeverQuests.CharacterFilter(source) end)
    local window, view, selectedId, chainCategory
    local browseIndex, browseBuilding, browsing
    local browse = { kind = "zones", page = 1, offset = 0 }
    local browseStates, rewardStates = {}, {}
    local rewardCatalog, rewardBuilding, rewardState
    local searchResults, searchMessage, searchOffset = {}, "Search by name or quest ID.", 0
    local player = ForeverQuests.Player()

    local function questLogStatus(id)
        return ns.Chain.QuestLogStatus(id, player)
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
            window.questDetails:Render(quest, rewardView, requirementText(quest), ForeverQuests.ReadLogDetails(id))
        end
    end

    local rewards = ns.Rewards.New({
        request = C_QuestLog.RequestLoadQuestByID,
        after = C_Timer.After,
        read = ForeverQuests.ReadRewards,
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
        window.timeline:Render(view, selectedId, statuses, scrollToId, chainCategory)
    end

    local function selectStep(id, scrollToId)
        selectedId = id
        window:OpenQuestPage()
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
        window:ShowJournal()
        selectStep(id, id)
        return true
    end

    local function showActiveChains()
        if not browseIndex then
            window.activeChains:Render({}, browseBuilding and "Loading active chains..." or "Quest chains unavailable.")
            return
        end
        local logged = ForeverQuests.ActiveLog(questLogStatus)
        local groups, count = browseIndex:ActiveChainGroups(logged)
        window.activeChains:Render(groups, nil, count)
    end

    local function search(query)
        local results = model:Search(query)
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
                return ns.RewardCatalog.Build(source, yieldWork)
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
            window = ns.Window.New({
                search = search, openQuest = openQuest, selectStep = selectStep,
                openJournalRoute = openJournalRoute,
                categoryName = function(kind, key)
                    local category = browseIndex and browseIndex:Category(kind, key)
                    return category and category.name
                end,
                currentZone = function()
                    return browseIndex and browseIndex:MatchZone(C_Map.GetBestMapForUnit("player"))
                end,
                openClassQuests = function()
                    local _, token = UnitClass("player")
                    window:OpenCategory("classes", token)
                end,
                openLinkedQuest = function(id) openQuest(id, nil, chainCategory) end,
                openBrowseCategory = function(kind, category)
                    if category then window:OpenCategory(kind, category) else window:OpenLocations(kind) end
                end,
                questLogStatus = questLogStatus,
                openActiveChains = openActiveChains,
                partyOnQuest = ForeverQuests.PartyOnQuest,
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

    function controller:Toggle()
        getWindow():Toggle()
    end

    function controller:OpenFromQuestLog(id)
        getWindow()
        if not openQuest(id) then
            print("QuestChain: Quest #" .. id .. " is unavailable for this character.")
        end
    end

    local partyEvents = {
        GROUP_ROSTER_UPDATE = true,
        UNIT_QUEST_LOG_CHANGED = true,
        PARTY_MEMBER_ENABLE = true,
        PARTY_MEMBER_DISABLE = true,
    }
    function controller:OnEvent(event, id, success)
        if event == "UNIT_QUEST_LOG_CHANGED" and id == "player" then event = "QUEST_LOG_UPDATE" end
        if partyEvents[event] then
            if not window or (event == "UNIT_QUEST_LOG_CHANGED" and not (id and id:match("^party%d+$"))) then
                return
            end
            refreshChain()
            if not browsing and #searchResults > 0 then
                window.questList:ShowResults(searchResults, searchMessage, window.questList:Offset())
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
            if window:IsActiveChainsOpen() then showActiveChains() end
            if browsing and browseIndex and browse.category then
                showBrowse(window.questList:Offset())
            elseif not browsing and #searchResults > 0 then
                window.questList:ShowResults(searchResults, searchMessage, window.questList:Offset())
            end
        end
    end

    return controller
end
