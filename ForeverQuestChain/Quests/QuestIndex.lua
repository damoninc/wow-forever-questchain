local _, ns = ...

---@class QuestIndex
---@field private questRepository QuestRepository
---@field private characterState CharacterQuestState
---@field private quests table<number, QuestSummary>?
---@field private visibleQuests table<number, QuestSummary>?
---@field private neighbors table<number, QuestChainEdge[]>?
local QuestIndex = {}
QuestIndex.__index = QuestIndex
ns.QuestIndex = QuestIndex

local QuestRequirements = ns.QuestRequirements

---@param questRepository QuestRepository
---@param characterState CharacterQuestState
---@return QuestIndex
function QuestIndex.New(questRepository, characterState)
    return setmetatable({ questRepository = questRepository, characterState = characterState }, QuestIndex)
end

local function buildCatalog(self, yieldWork)
    local quests, visible, neighbors = {}, {}, {}
    local identity = self.characterState:GetIdentity()
    local ids = self.questRepository:ListIds()
    local function yieldAndCheck(index)
        if yieldWork and index % 80 == 0 then
            yieldWork()
        end
        -- Search can finish the catalog while an incremental build is suspended.
        return self.quests ~= nil
    end
    for index, id in ipairs(ids) do
        local quest = self.questRepository:GetSummary(id)
        quests[id] = quest
        if quest and QuestRequirements.IsEligible(quest, identity) then
            visible[id] = quest
        end
        if yieldAndCheck(index) then return end
    end

    local function connect(fromId, toId, kind)
        -- Keep missing references for partial-data reporting and skip known ineligible steps.
        if (quests[fromId] and not visible[fromId]) or (quests[toId] and not visible[toId]) then
            return
        end
        local edge = { fromId = fromId, toId = toId, kind = kind }
        neighbors[fromId] = neighbors[fromId] or {}
        table.insert(neighbors[fromId], edge)
        if toId ~= fromId then
            neighbors[toId] = neighbors[toId] or {}
            table.insert(neighbors[toId], edge)
        end
    end

    for index, id in ipairs(ids) do
        local quest = visible[id]
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
    self.quests, self.visibleQuests, self.neighbors = quests, visible, neighbors
end

---@param yieldWork? fun()
---@return table<number, QuestSummary>, table<number, QuestChainEdge[]>
function QuestIndex:Catalog(yieldWork)
    if not self.quests then
        buildCatalog(self, yieldWork)
    end
    return self.visibleQuests, self.neighbors
end

-- Look up an unrestricted summary without forcing a catalog build.
---@param id number
---@return QuestSummary?
function QuestIndex:Get(id)
    if self.quests then
        return self.quests[id]
    end
    return self.questRepository:GetSummary(id)
end
