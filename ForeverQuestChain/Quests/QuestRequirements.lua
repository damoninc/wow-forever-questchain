local _, ns = ...

local QuestRequirements = {}
ns.QuestRequirements = QuestRequirements

---@param quest QuestSummary
---@param identity QuestCharacterIdentity?
---@return boolean
function QuestRequirements.IsEligible(quest, identity)
    local restrictions = quest.restrictions
    if not restrictions or not identity then
        return true
    end
    local raceDecision = restrictions.byRaceId and restrictions.byRaceId[identity.raceId]
    if raceDecision ~= nil then
        return raceDecision
    end
    local factionDecision = restrictions.byFaction and restrictions.byFaction[identity.faction]
    return factionDecision ~= false
end

---@param quest QuestSummary
---@param index QuestIndex
---@return number[]
function QuestRequirements.MissingIds(quest, index)
    local missing = {}
    for _, group in ipairs({ quest.allOf or {}, quest.anyOf or {} }) do
        for _, id in ipairs(group) do
            id = math.abs(id)
            if not index:Get(id) then
                missing[#missing + 1] = id
            end
        end
    end
    return missing
end

local function isUncertain(quest, view, index)
    if #(quest.allOf or {}) > 0 and #(quest.anyOf or {}) > 0 then
        return true
    end
    if view then
        return view.uncertainIds[quest.id] == true
    end
    return #QuestRequirements.MissingIds(quest, index) > 0
end

local function alternatives(id, index)
    local required = id > 0 and index:Get(id)
    return required and required.exclusiveTo or {}
end

---@class QuestRequirementOption
---@field questId number
---@field alternativeIds number[]

---@class QuestRequirementGroup
---@field kind "all"|"any"
---@field options QuestRequirementOption[]

---@class QuestRequirementDescription
---@field uncertain boolean
---@field groups QuestRequirementGroup[]

---@param quest QuestSummary
---@param view QuestChainView?
---@param index QuestIndex
---@return QuestRequirementDescription
function QuestRequirements.Describe(quest, view, index)
    local groups = {}
    if #(quest.allOf or {}) > 0 then
        local options = {}
        for _, id in ipairs(quest.allOf) do
            options[#options + 1] = { questId = math.abs(id), alternativeIds = alternatives(id, index) }
        end
        groups[#groups + 1] = { kind = "all", options = options }
    end
    if #(quest.anyOf or {}) > 0 then
        local options = {}
        for _, id in ipairs(quest.anyOf) do
            options[#options + 1] = { questId = math.abs(id), alternativeIds = {} }
        end
        groups[#groups + 1] = { kind = "any", options = options }
    end
    return { uncertain = isUncertain(quest, view, index), groups = groups }
end

local function isSatisfied(id, index, isCompleted)
    if isCompleted(math.abs(id)) then
        return true
    end
    for _, alternative in ipairs(alternatives(id, index)) do
        if isCompleted(alternative) then
            return true
        end
    end
    return false
end

---@param quest QuestSummary
---@param view QuestChainView?
---@param index QuestIndex
---@param isCompleted fun(questId: number): boolean
---@return "any"|"all"|nil
function QuestRequirements.UnmetGroup(quest, view, index, isCompleted)
    if isUncertain(quest, view, index) then
        return nil
    end
    local anyOf = quest.anyOf or {}
    if #anyOf > 0 then
        for _, id in ipairs(anyOf) do
            if isCompleted(id) then
                return nil
            end
        end
        return "any"
    end
    for _, id in ipairs(quest.allOf or {}) do
        if not isSatisfied(id, index, isCompleted) then
            return "all"
        end
    end
end
