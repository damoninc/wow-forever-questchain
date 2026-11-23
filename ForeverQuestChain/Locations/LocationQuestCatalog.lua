local _, ns = ...

---@class LocationQuestCatalog
local LocationQuestCatalog = {}
LocationQuestCatalog.__index = LocationQuestCatalog
ns.LocationQuestCatalog = LocationQuestCatalog

local QuestProgress = ns.QuestProgress
local selectionPriority = QuestProgress.SelectionPriority
local QuestLocationContext = ns.QuestLocationContext
local QuestRequirements = ns.QuestRequirements

local unknownZone = { key = 0, name = "Unknown pickup zone" }

local function dungeonLevelRange(levels)
    table.sort(levels)
    local first, last = 1, #levels
    if last >= 8 then
        -- Use quartile fences to reject outliers. Leave room for uncommon
        -- levels around the main cluster when most quests share a level.
        local quarter = math.ceil(last / 4)
        local lower, upper = levels[quarter], levels[last - quarter + 1]
        local padding = math.max(8, 1.5 * (upper - lower))
        while levels[first] < lower - padding do first = first + 1 end
        while levels[last] > upper + padding do last = last - 1 end
    end
    return levels[first], levels[last]
end

local function rootOf(nodes, id)
    while nodes[id].root ~= id do
        nodes[id].root = nodes[nodes[id].root].root
        id = nodes[id].root
    end
    return id
end

local function groupQuests(questIndex, quests, neighbors, ids)
    local nodes, components = {}, {}
    for _, id in ipairs(ids) do
        nodes[id] = { root = id, incoming = 0, children = {}, parents = {}, optional = {} }
    end
    for _, id in ipairs(ids) do
        local node = nodes[id]
        for _, edge in ipairs(neighbors[id] or {}) do
            local targetId = edge.toId
            local target = nodes[targetId]
            if edge.fromId == id and target and target ~= node then
                if edge.kind == "breadcrumb" or edge.kind == "substitute" then
                    node.optional[#node.optional + 1] = targetId
                else
                    local a, b = rootOf(nodes, id), rootOf(nodes, targetId)
                    nodes[math.max(a, b)].root = math.min(a, b)
                    target.incoming = target.incoming + 1
                    node.children[#node.children + 1] = targetId
                    target.parents[#target.parents + 1] = id
                end
            elseif edge.fromId == id and not target and edge.kind ~= "breadcrumb" and edge.kind ~= "substitute" then
                node.missingSuccessor = true
            elseif edge.toId == id and not nodes[edge.fromId] and edge.kind ~= "breadcrumb" and edge.kind ~= "substitute" then
                node.parents[#node.parents + 1] = edge.fromId
            end
        end
    end
    local queue = {}
    for _, id in ipairs(ids) do
        local node = nodes[id]
        local key = rootOf(nodes, id)
        local group = components[key] or {
            key = key, members = {}, endings = {}, steps = {}, predecessors = {}, requiredOptions = {},
        }
        components[key] = group
        local quest = quests[id]
        group.members[#group.members + 1] = quest
        group.predecessors[id] = node.parents
        if #(quest.allOf or {}) > 0 then
            local requirements = QuestRequirements.Describe(quest, nil, questIndex)
            if not requirements.uncertain then
                group.requiredOptions[id] = requirements.groups[1].options
            end
        end
        group.missingSuccessor = group.missingSuccessor or node.missingSuccessor
        if #node.children == 0 and not node.missingSuccessor then
            group.endings[#group.endings + 1] = quests[id]
        end
        node.group = group
        if node.incoming == 0 then
            group.start = group.start or id
            queue[#queue + 1] = id
        end
    end
    local index = 1
    while queue[index] do
        local node = nodes[queue[index]]
        node.order = index
        index = index + 1
        for _, child in ipairs(node.children) do
            local nextNode = nodes[child]
            nextNode.incoming = nextNode.incoming - 1
            if nextNode.incoming == 0 then
                queue[#queue + 1] = child
            end
        end
    end
    for _, id in ipairs(ids) do
        if not nodes[id].order then
            nodes[id].order = index
            index = index + 1
        end
    end
    for _, id in ipairs(ids) do
        local node = nodes[id]
        if #node.group.members == 1 and #node.optional > 0 then
            local destination
            for _, targetId in ipairs(node.optional) do
                local target = nodes[targetId]
                if destination and destination.group ~= target.group then
                    destination = nil
                    break
                end
                if not destination or target.order < destination.order then
                    destination = target
                    node.destination = targetId
                end
            end
            -- Retain each destination's structural identity, even if it is
            -- itself an optional-only quest assigned to another group.
            if destination and destination.group ~= node.group then
                node.browseGroup = destination.group
                destination.group.hasOptional = true
                node.order = destination.order - 0.5
            else
                node.destination = nil
            end
        end
    end
    for _, group in pairs(components) do
        group.title = quests[group.start or group.key].title
        group.standalone = #group.members == 1 and not group.hasOptional
    end
    return nodes
end

---@param locationRepository QuestLocationRepository
---@param mapMetadata MapMetadata
function LocationQuestCatalog.Build(questIndex, locationRepository, mapMetadata, yieldWork)
    local quests, neighbors = questIndex:Catalog(yieldWork)
    local ids = {}
    for id in pairs(quests) do ids[#ids + 1] = id end
    table.sort(ids)
    local nodes = groupQuests(questIndex, quests, neighbors, ids)
    local byKind = { zones = {}, dungeons = {}, classes = {} }
    local steps, dungeonLevels = {}, {}
    local function add(kind, category, step, chain)
        local index = byKind[kind]
        local bucket = index[category.key]
        if not bucket then
            bucket = { key = category.key, name = category.name, byGroup = {}, groups = {} }
            if category.mapId then
                bucket.minLevel, bucket.maxLevel = mapMetadata:GetLevelRange(category.mapId)
                bucket.hasMapLevels = bucket.minLevel ~= nil
            end
            index[category.key] = bucket
        end
        local group = bucket.byGroup[chain.key]
        if not group then
            group = { key = chain.key, title = chain.title, standalone = chain.standalone, steps = {}, chain = chain }
            bucket.byGroup[chain.key] = group
            bucket.groups[#bucket.groups + 1] = group
        end
        group.steps[#group.steps + 1] = step
        local level = step.quest.level
        local belongs = kind ~= "dungeons" or (step.dungeon and step.dungeon.key == category.key)
        if level and belongs then
            group.level = math.min(group.level or level, level)
            if kind == "dungeons" and not bucket.hasMapLevels then
                local levels = dungeonLevels[category.key] or {}
                dungeonLevels[category.key] = levels
                levels[#levels + 1] = level
            elseif kind == "zones" and bucket.key ~= unknownZone.key and not bucket.hasMapLevels then
                bucket.minLevel = math.min(bucket.minLevel or level, level)
                bucket.maxLevel = math.max(bucket.maxLevel or level, level)
            end
        end
    end
    for index, id in ipairs(ids) do
        local quest, node = quests[id], nodes[id]
        local chain = node.browseGroup or node.group
        local dungeon = locationRepository:GetDungeon(id)
        local zones = locationRepository:GetPickupZones(id)
        if #zones == 0 then zones = { unknownZone } end
        local step = {
            quest = quest, order = node.order, destination = node.destination,
            dungeon = dungeon, chain = chain, pickupZones = zones,
        }
        steps[id] = step
        chain.steps[#chain.steps + 1] = step
        for _, category in ipairs(zones) do add("zones", category, step, chain) end
        if dungeon then
            chain.dungeons = chain.dungeons or {}
            chain.dungeons[dungeon.key] = dungeon
        end
        for _, category in ipairs(locationRepository:GetClassCategories(id)) do
            add("classes", category, step, chain)
        end
        if yieldWork and index % 80 == 0 then yieldWork() end
    end
    -- A verified dungeon quest anchors the group. Show the rest of that
    -- chain as context without giving those quests a new dungeon assignment.
    for index, id in ipairs(ids) do
        local step = steps[id]
        local chain = step.chain
        if chain.dungeons then
            for _, dungeon in pairs(chain.dungeons) do add("dungeons", dungeon, step, chain) end
        end
        if yieldWork and index % 80 == 0 then yieldWork() end
    end
    for key, levels in pairs(dungeonLevels) do
        local bucket = byKind.dungeons[key]
        bucket.minLevel, bucket.maxLevel = dungeonLevelRange(levels)
    end
    return setmetatable({ byKind = byKind, mapMetadata = mapMetadata, steps = steps }, LocationQuestCatalog)
end

local function byName(left, right)
    local a, b = left.name:lower(), right.name:lower()
    if a == b then return left.key < right.key end
    return a < b
end

function LocationQuestCatalog:Categories(kind)
    local results = {}
    for _, category in pairs(self.byKind[kind]) do results[#results + 1] = category end
    table.sort(results, function(left, right)
        local leftLevel, rightLevel = left.minLevel or math.huge, right.minLevel or math.huge
        if kind ~= "classes" and leftLevel ~= rightLevel then return leftLevel < rightLevel end
        return byName(left, right)
    end)
    return results
end

function LocationQuestCatalog:Category(kind, key)
    return self.byKind[kind][key]
end

function LocationQuestCatalog:Groups(kind, key)
    local category = self:Category(kind, key)
    if not category then return {} end
    if not category.sorted then
        table.sort(category.groups, function(a, b)
            local aLevel, bLevel = a.level or math.huge, b.level or math.huge
            if aLevel ~= bLevel then
                return aLevel < bLevel
            end
            local left, right = a.title:lower(), b.title:lower()
            if left == right then return a.key < b.key end
            return left < right
        end)
        for _, group in ipairs(category.groups) do
            table.sort(group.steps, function(a, b)
                if a.order == b.order then return a.quest.id < b.quest.id end
                return a.order < b.order
            end)
        end
        category.sorted = true
    end
    return category.groups
end

function LocationQuestCatalog:MatchZone(mapId)
    return QuestLocationContext.FindMapCategory(self.mapMetadata, mapId, self.byKind.zones)
end

function LocationQuestCatalog:GetStep(questId)
    return self.steps[questId]
end

function LocationQuestCatalog:Rows(kind, key, filter, getStatus)
    local rows, standalone = {}, {}
    local statuses = {}
    local function statusOf(id)
        if not statuses[id] then statuses[id] = getStatus(id) or "unstarted" end
        return statuses[id]
    end
    for _, group in ipairs(self:Groups(kind, key)) do
        local chainStatus
        if not group.standalone then
            chainStatus = QuestProgress.ChainStatus(group.chain, statusOf)
        end
        local selected, selectedStatus, priority = nil, nil, 0
        local completed = 0
        for _, step in ipairs(group.steps) do
            local status = statusOf(step.quest.id)
            local done = status == "completed"
            if done then completed = completed + 1 end
            local matches = not filter or (filter == "completed" and done) or (filter == "incomplete" and not done)
            local rank = chainStatus == "completed" and done and math.huge or selectionPriority[status]
            if matches and (rank > priority or (done and rank == priority)) then
                selected, selectedStatus, priority = step, status, rank
            end
        end
        if chainStatus == "completed" then
            -- A completed chain can have only skipped steps in this category.
            selected = filter ~= "incomplete" and (selected or group.steps[1]) or nil
        end
        if selected then
            local list = group.standalone and standalone or rows
            list[#list + 1] = { group = group, step = selected, status = chainStatus or selectedStatus, completed = completed }
        end
    end
    for _, row in ipairs(standalone) do rows[#rows + 1] = row end
    return rows
end

function LocationQuestCatalog.Page(rows, page)
    local pageSize = 40
    local total = math.max(1, math.ceil(#rows / pageSize))
    page = math.max(1, math.min(page, total))
    local first = (page - 1) * pageSize + 1
    local result = {}
    for index = first, math.min(#rows, first + pageSize - 1) do
        result[#result + 1] = rows[index]
    end
    return result, page, total
end
