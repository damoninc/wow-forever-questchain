local _, ns = ...

local Browse = {}
Browse.__index = Browse
ns.Browse = Browse

local unknownZone = { key = 0, name = "Unknown pickup zone" }

local function rootOf(nodes, id)
    while nodes[id].root ~= id do
        nodes[id].root = nodes[nodes[id].root].root
        id = nodes[id].root
    end
    return id
end

local function groupQuests(quests, neighbors, ids)
    local nodes, components = {}, {}
    for _, id in ipairs(ids) do
        nodes[id] = { root = id, incoming = 0, children = {}, optional = {} }
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
                end
            end
        end
    end
    local queue = {}
    for _, id in ipairs(ids) do
        local node = nodes[id]
        local key = rootOf(nodes, id)
        local group = components[key] or { key = key, count = 0 }
        components[key] = group
        group.count = group.count + 1
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
    for _, group in pairs(components) do
        group.title = quests[group.start or group.key].title
    end
    for _, id in ipairs(ids) do
        local node = nodes[id]
        if node.group.count == 1 and #node.optional > 0 then
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
    return nodes
end

function Browse.Build(model, source, yieldWork)
    local quests, neighbors = model:Catalog(yieldWork)
    local ids = {}
    for id in pairs(quests) do ids[#ids + 1] = id end
    table.sort(ids)
    local nodes = groupQuests(quests, neighbors, ids)
    local byKind = { zones = {}, dungeons = {}, classes = {} }
    local steps = {}
    local function add(kind, category, step, chain)
        local index = byKind[kind]
        local bucket = index[category.key]
        if not bucket then
            bucket = { key = category.key, name = category.name, byGroup = {}, groups = {} }
            if kind ~= "classes" and source.categoryLevels then
                bucket.minLevel, bucket.maxLevel = source.categoryLevels(kind, category.key)
                bucket.hasMapLevels = bucket.minLevel ~= nil
            end
            index[category.key] = bucket
        end
        local group = bucket.byGroup[chain.key]
        if not group then
            group = { key = chain.key, title = chain.title, standalone = chain.count == 1 and not chain.hasOptional, steps = {} }
            bucket.byGroup[chain.key] = group
            bucket.groups[#bucket.groups + 1] = group
        end
        group.steps[#group.steps + 1] = step
        local level = step.quest.level
        local belongs = kind ~= "dungeons" or (step.dungeon and step.dungeon.key == category.key)
        if level and belongs then
            group.level = math.min(group.level or level, level)
            if kind ~= "classes" and bucket.key ~= unknownZone.key and not bucket.hasMapLevels then
                bucket.minLevel = math.min(bucket.minLevel or level, level)
                bucket.maxLevel = math.max(bucket.maxLevel or level, level)
            end
        end
    end
    for index, id in ipairs(ids) do
        local quest, node = quests[id], nodes[id]
        local chain = node.browseGroup or node.group
        local dungeon = source.dungeon(quest.areaId)
        local step = { quest = quest, order = node.order, destination = node.destination, dungeon = dungeon }
        steps[index] = step
        local zones = source.pickupZones(id)
        if #zones == 0 then zones = { unknownZone } end
        for _, category in ipairs(zones) do add("zones", category, step, chain) end
        if dungeon then
            chain.dungeons = chain.dungeons or {}
            chain.dungeons[dungeon.key] = dungeon
        end
        for _, category in ipairs(source.classes(quest.zoneOrSort, quest.classMask)) do
            add("classes", category, step, chain)
        end
        if yieldWork and index % 80 == 0 then yieldWork() end
    end
    -- A verified dungeon quest anchors the group. Show the rest of that
    -- chain as context without giving those quests a new dungeon assignment.
    for index, step in ipairs(steps) do
        local node = nodes[step.quest.id]
        local chain = node.browseGroup or node.group
        if chain.dungeons then
            for _, dungeon in pairs(chain.dungeons) do add("dungeons", dungeon, step, chain) end
        end
        if yieldWork and index % 80 == 0 then yieldWork() end
    end
    return setmetatable({ byKind = byKind, source = source }, Browse)
end

local function byName(left, right)
    local a, b = left.name:lower(), right.name:lower()
    if a == b then return left.key < right.key end
    return a < b
end

function Browse:Categories(kind)
    local results = {}
    for _, category in pairs(self.byKind[kind]) do results[#results + 1] = category end
    table.sort(results, function(left, right)
        local leftLevel, rightLevel = left.minLevel or math.huge, right.minLevel or math.huge
        if kind ~= "classes" and leftLevel ~= rightLevel then return leftLevel < rightLevel end
        return byName(left, right)
    end)
    return results
end

function Browse:Groups(kind, key)
    local category = self.byKind[kind][key]
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

function Browse:MatchZone(mapId)
    local seen = {}
    while mapId and mapId > 0 and not seen[mapId] do
        local category = self.byKind.zones[mapId]
        if category then return category end
        seen[mapId] = true
        mapId = self.source.zoneParent(mapId)
    end
end

function Browse:Rows(kind, key, collapsed, isHidden)
    local rows = {}
    for _, group in ipairs(self:Groups(kind, key)) do
        local steps = {}
        for _, step in ipairs(group.steps) do
            if not isHidden(step.quest.id) then steps[#steps + 1] = step end
        end
        if #steps > 0 then
            if not group.standalone then
                rows[#rows + 1] = { group = group }
            end
            if not collapsed[group.key] then
                for _, step in ipairs(steps) do
                    rows[#rows + 1] = { step = step, group = group }
                end
            end
        end
    end
    return rows
end

function Browse.Page(rows, page)
    local pageSize = 40
    local total = math.max(1, math.ceil(#rows / pageSize))
    page = math.max(1, math.min(page, total))
    local first = (page - 1) * pageSize + 1
    local result = {}
    local firstRow, previous = rows[first], rows[first - 1]
    if firstRow and firstRow.step and previous and firstRow.group == previous.group then
        result[1] = { group = firstRow.group }
    end
    for index = first, math.min(#rows, first + pageSize - 1) do
        result[#result + 1] = rows[index]
    end
    return result, page, total
end
