local _, ns = ...

---@class QuestChainEdge
---@field fromId number
---@field toId number
---@field kind "breadcrumb"|"substitute"|"sequence"|"any"|"all"

---@class QuestChainView
---@field focusId number
---@field quests QuestSummary[]
---@field edges QuestChainEdge[]
---@field missingIds number[]
---@field omittedIds number[]
---@field uncertainIds table<number, boolean>

---@class QuestChain
---@field private index QuestIndex
local QuestChain = {}
QuestChain.__index = QuestChain
ns.QuestChain = QuestChain

local QuestRequirements = ns.QuestRequirements
local edgePriority = { breadcrumb = 1, substitute = 2, sequence = 3, any = 4, all = 4 }

---@param index QuestIndex
---@return QuestChain
function QuestChain.New(index)
    return setmetatable({ index = index }, QuestChain)
end

local function insert(list, value)
    list[#list + 1] = value
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

local function breadcrumbDestination(edges, focusId, visible)
    local destination
    for _, edge in ipairs(edges or {}) do
        local target = edge.toId
        if edge.kind == "breadcrumb" and edge.fromId == focusId and target ~= focusId and visible[target] then
            if destination and destination ~= target then return nil end
            destination = target
        end
    end
    return destination
end

---@param focusId number
---@param limit? number
---@param destination? number
---@return QuestChainView?
function QuestChain:Build(focusId, limit, destination)
    local questIndex = self.index
    local visible, neighbors = questIndex:Catalog()
    if not visible[focusId] then
        return nil
    end
    limit = math.max(1, limit or 100)
    local leadInDestination = not destination and breadcrumbDestination(neighbors[focusId], focusId, visible)

    local included = { [focusId] = true }
    local queue, adjacent, omitted, missing = { focusId }, {}, {}, {}
    local index = 1
    while queue[index] do
        local id = queue[index]
        index = index + 1
        for _, edge in ipairs(neighbors[id] or {}) do
            local other = otherEnd(edge, id)
            if not questIndex:Get(other) then
                missing[other] = true
            elseif not included[other] then
                local optional = edge.kind == "breadcrumb" or edge.kind == "substitute"
                local followOptional = id == focusId and id == edge.fromId
                    and (other == destination or other == leadInDestination or (not destination and edge.kind == "substitute"))
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
        for _, edge in ipairs(neighbors[id] or {}) do
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
        for _, prerequisite in ipairs(QuestRequirements.MissingIds(visible[id], questIndex)) do
            uncertain[id] = true
            missing[prerequisite] = true
        end
    end

    local ordered, positions = {}, {}
    local ids = sortedIds(included)
    local function appendQuest(id)
        insert(ordered, visible[id])
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
