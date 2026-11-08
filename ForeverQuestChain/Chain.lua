local _, ns = ...

local Chain = {}
Chain.__index = Chain
ns.Chain = Chain

local edgePriority = { breadcrumb = 1, substitute = 2, sequence = 3, any = 4, all = 4 }

local function insert(list, value)
    list[#list + 1] = value
end

function Chain.New(source)
    return setmetatable({ source = source }, Chain)
end

function Chain:Index(yieldWork)
    if self.quests then
        return
    end
    local quests, neighbors = {}, {}
    local readSummary = self.source.summary or self.source.read
    local ids = self.source.ids()
    local function yieldAndCheck(index)
        if yieldWork and index % 80 == 0 then
            yieldWork()
        end
        return self.quests ~= nil
    end
    for index, id in ipairs(ids) do
        quests[id] = readSummary(id)
        if yieldAndCheck(index) then return end
    end

    local function connect(fromId, toId, kind)
        local edge = { fromId = fromId, toId = toId, kind = kind }
        neighbors[fromId] = neighbors[fromId] or {}
        insert(neighbors[fromId], edge)
        if toId ~= fromId then
            neighbors[toId] = neighbors[toId] or {}
            insert(neighbors[toId], edge)
        end
    end

    for index, id in ipairs(ids) do
        local quest = quests[id]
        if quest then
            for _, target in ipairs(quest.successors or {}) do
                connect(id, target, "sequence")
            end
            if quest.parentId then
                connect(quest.parentId, id, "sequence")
            end
            for _, prerequisite in ipairs(quest.anyOf or {}) do
                connect(prerequisite, id, "any")
            end
            for _, prerequisite in ipairs(quest.allOf or {}) do
                connect(math.abs(prerequisite), id, "all")
                local required = prerequisite > 0 and quests[prerequisite]
                if required then
                    for _, alternative in ipairs(required.exclusiveTo or {}) do
                        connect(alternative, id, "substitute")
                    end
                end
            end
            for _, breadcrumb in ipairs(quest.breadcrumbs or {}) do
                connect(breadcrumb, id, "breadcrumb")
            end
            if quest.breadcrumbTarget then
                connect(id, quest.breadcrumbTarget, "breadcrumb")
            end
        end
        if yieldAndCheck(index) then return end
    end
    self.quests, self.neighbors = quests, neighbors
end

function Chain:Search(query)
    query = query:match("^%s*(.-)%s*$"):lower()
    if query == "" then
        return {}
    end
    self:Index()
    if query:match("^%d+$") then
        local quest = self.quests[tonumber(query)]
        return quest and { quest } or {}
    end
    local results = {}
    for _, quest in pairs(self.quests) do
        if quest.title:lower():find(query, 1, true) then
            insert(results, quest)
        end
    end
    table.sort(results, function(left, right)
        local a, b = left.title:lower(), right.title:lower()
        if a == b then
            return left.id < right.id
        end
        if a == query or b == query then
            return a == query
        end
        return a < b
    end)
    return results
end

function Chain:GetQuest(id)
    return self.source.read(id)
end

function Chain:Catalog(yieldWork)
    self:Index(yieldWork)
    return self.quests, self.neighbors
end

local function sortedIds(set)
    local ids = {}
    for id in pairs(set) do
        insert(ids, id)
    end
    table.sort(ids)
    return ids
end

local function otherEnd(edge, id)
    if edge.fromId == id then
        return edge.toId
    end
    return edge.fromId
end

function Chain:Build(focusId, limit, destination)
    self:Index()
    if not self.quests[focusId] then
        return nil
    end
    limit = math.max(1, limit or 100)

    local included = { [focusId] = true }
    local queue, adjacent, omitted, missing = { focusId }, {}, {}, {}
    local index = 1
    while queue[index] do
        local id = queue[index]
        index = index + 1
        for _, edge in ipairs(self.neighbors[id] or {}) do
            local other = otherEnd(edge, id)
            if not self.quests[other] then
                missing[other] = true
            elseif not included[other] then
                local optional = edge.kind == "breadcrumb" or edge.kind == "substitute"
                local followOptional = id == focusId and id == edge.fromId
                    and (other == destination or (not destination and edge.kind == "substitute"))
                if optional and not followOptional then
                    adjacent[other] = true
                elseif #queue < limit then
                    included[other] = true
                    insert(queue, other)
                else
                    omitted[other] = true
                end
            end
        end
    end
    for _, id in ipairs(sortedIds(adjacent)) do
        if not included[id] then
            if #queue < limit then
                included[id] = true
                insert(queue, id)
            else
                omitted[id] = true
            end
        end
    end

    local edges, outgoing, degree, uncertain = {}, {}, {}, {}
    for _, id in ipairs(queue) do
        degree[id] = 0
    end
    for _, id in ipairs(queue) do
        local byTarget = {}
        for _, edge in ipairs(self.neighbors[id] or {}) do
            if edge.fromId == id and included[edge.toId] then
                local existing = byTarget[edge.toId]
                if not existing or edgePriority[edge.kind] > edgePriority[existing.kind] then
                    byTarget[edge.toId] = edge
                end
            end
        end
        outgoing[id] = {}
        for _, target in ipairs(sortedIds(byTarget)) do
            local edge = byTarget[target]
            insert(edges, edge)
            if edge.kind ~= "breadcrumb" and edge.kind ~= "substitute" then
                insert(outgoing[id], target)
                degree[target] = degree[target] + 1
            end
        end
        local quest = self.quests[id]
        for _, group in ipairs({ quest.allOf or {}, quest.anyOf or {} }) do
            for _, prerequisite in ipairs(group) do
                prerequisite = math.abs(prerequisite)
                if not self.quests[prerequisite] then
                    uncertain[id] = true
                    missing[prerequisite] = true
                end
            end
        end
    end

    local ordered, positions = {}, {}
    local ids = sortedIds(included)
    local function appendQuest(id)
        insert(ordered, self.quests[id])
        positions[id] = #ordered
        for _, target in ipairs(outgoing[id]) do
            degree[target] = degree[target] - 1
        end
    end
    while #ordered < #ids do
        local count = #ordered
        for _, id in ipairs(ids) do
            if not positions[id] and degree[id] == 0 then
                appendQuest(id)
            end
        end
        if #ordered == count then
            for _, id in ipairs(ids) do
                if not positions[id] then
                    uncertain[id] = true
                    appendQuest(id)
                end
            end
        end
    end
    table.sort(edges, function(a, b)
        if a.fromId == b.fromId then
            return positions[a.toId] < positions[b.toId]
        end
        return positions[a.fromId] < positions[b.fromId]
    end)

    return {
        focusId = focusId,
        quests = ordered,
        edges = edges,
        missingIds = sortedIds(missing),
        omittedIds = sortedIds(omitted),
        uncertainIds = uncertain,
    }
end

function Chain:Status(id, player, view)
    if player.isActive(id) then
        return player.isReady(id) and "ready" or "active"
    end
    if player.isCompleted(id) then
        return "completed"
    end
    local quest = self.quests[id]
    if quest.minLevel and player.level < quest.minLevel then
        return "blocked", "Requires level " .. quest.minLevel
    end
    local anyOf, allOf = quest.anyOf or {}, quest.allOf or {}
    if view.uncertainIds[id] or (#anyOf > 0 and #allOf > 0) then
        return "unstarted"
    end
    if #anyOf > 0 then
        for _, prerequisite in ipairs(anyOf) do
            if player.isCompleted(prerequisite) then
                return "unstarted"
            end
        end
        return "blocked", "Complete one prerequisite"
    end
    for _, prerequisite in ipairs(allOf) do
        local complete = player.isCompleted(math.abs(prerequisite))
        if not complete and prerequisite > 0 then
            for _, alternative in ipairs(self.quests[prerequisite].exclusiveTo or {}) do
                if player.isCompleted(alternative) then
                    complete = true
                    break
                end
            end
        end
        if not complete then
            return "blocked", "Complete required prerequisites"
        end
    end
    return "unstarted"
end
