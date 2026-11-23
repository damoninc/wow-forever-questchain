local _, ns = ...

---@class ActiveChainsQuery
local ActiveChainsQuery = {}
ActiveChainsQuery.__index = ActiveChainsQuery
ns.ActiveChainsQuery = ActiveChainsQuery

local selectionPriority = ns.QuestProgress.SelectionPriority

---@param characterState CharacterQuestState
function ActiveChainsQuery.New(characterState, questProgress)
    return setmetatable({ characterState = characterState, questProgress = questProgress }, ActiveChainsQuery)
end

function ActiveChainsQuery:Run(catalog)
    local active = {}
    for id, entry in pairs(self.characterState:ListLoggedQuests()) do
        local status = self.questProgress:GetLogStatus(id)
        if status == "active" or status == "ready" then
            active[id] = { status = status, zone = entry.zone, level = entry.level }
        end
    end
    return ActiveChainsQuery.Group(catalog, active)
end

function ActiveChainsQuery.Rows(catalog, logged)
    local rows, byChain = {}, {}
    for id, log in pairs(logged) do
        local step = catalog:GetStep(id)
        local chain = step and step.chain
        if chain and not chain.standalone then
            local row = byChain[chain.key]
            if not row then
                row = { key = chain.key, title = chain.title, count = 0, step = step, log = log }
                byChain[chain.key] = row
                rows[#rows + 1] = row
            end
            row.count = row.count + 1
            local priority, selectedPriority = selectionPriority[log.status], selectionPriority[row.log.status]
            if priority > selectedPriority or (priority == selectedPriority and step.order < row.step.order) then
                row.step, row.log = step, log
            end
        end
    end
    table.sort(rows, function(a, b)
        local aLevel = a.log.level or a.step.quest.level or math.huge
        local bLevel = b.log.level or b.step.quest.level or math.huge
        if aLevel ~= bLevel then return aLevel < bLevel end
        local left, right = a.title:lower(), b.title:lower()
        if left == right then return a.key < b.key end
        return left < right
    end)
    return rows
end

function ActiveChainsQuery.Group(catalog, logged)
    local rows = ActiveChainsQuery.Rows(catalog, logged)
    local zonesByChain = {}
    for id in pairs(logged) do
        local step = catalog:GetStep(id)
        local chain = step and step.chain
        if chain and not chain.standalone and not chain.dungeons then
            local locations = zonesByChain[chain.key] or {}
            zonesByChain[chain.key] = locations
            for _, zone in ipairs(step.pickupZones) do locations[zone.key] = zone end
        end
    end

    local groups, byLocation = {}, {}
    for _, row in ipairs(rows) do
        local dungeons = row.step.chain.dungeons
        local kind = dungeons and "dungeons" or "zones"
        for key, location in pairs(dungeons or zonesByChain[row.key]) do
            local identity = kind .. ":" .. key
            local group = byLocation[identity]
            if not group then
                group = { key = identity, kind = kind, category = catalog:Category(kind, key) or location, rows = {} }
                byLocation[identity] = group
                groups[#groups + 1] = group
            end
            group.rows[#group.rows + 1] = row
        end
    end
    table.sort(groups, function(a, b)
        local left, right = a.category, b.category
        local aLevel, bLevel = left.minLevel or math.huge, right.minLevel or math.huge
        if aLevel ~= bLevel then return aLevel < bLevel end
        if left.name:lower() ~= right.name:lower() then return left.name:lower() < right.name:lower() end
        return a.key < b.key
    end)
    return groups, #rows
end
