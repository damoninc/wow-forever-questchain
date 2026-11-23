local _, ns = ...

---@alias QuestLogStatus "active"|"ready"|"completed"
---@alias QuestStatus QuestLogStatus|"blocked"|"unstarted"

---@class QuestProgress
---@field private index QuestIndex
---@field private characterState CharacterQuestState
---@field private isCompleted fun(questId: number): boolean
local QuestProgress = {}
QuestProgress.__index = QuestProgress
ns.QuestProgress = QuestProgress

local QuestRequirements = ns.QuestRequirements
local unmetReasons = { any = "Complete one prerequisite", all = "Complete required prerequisites" }
QuestProgress.SelectionPriority = { ready = 4, active = 3, unstarted = 2, completed = 1 }

---@class QuestChainProgress
---@field members QuestSummary[] Quests connected by structural links.
---@field endings QuestSummary[] Structural members with no known successor.
---@field steps { quest: QuestSummary }[] Browse steps, including optional lead-ins.
---@field predecessors table<number, number[]> Incoming structural links by quest ID.
---@field requiredOptions table<number, QuestRequirementOption[]> Known all-required prerequisites by quest ID.
---@field missingSuccessor boolean? A structural link points to a missing quest.

---@param chain QuestChainProgress
---@param getStatus fun(questId: number): QuestLogStatus|"unstarted"
---@return "completed"|"active"|"unstarted"
function QuestProgress.ChainStatus(chain, getStatus)
    local completed, skipped, started = {}, {}, false
    for _, step in ipairs(chain.steps) do
        local quest = step.quest
        local status = getStatus(quest.id)
        started = started or status ~= "unstarted"
        if status == "completed" then
            completed[quest.id] = true
            for _, other in ipairs(quest.exclusiveTo or {}) do skipped[other] = true end
        end
    end
    if not started then return "unstarted" end
    if chain.missingSuccessor then return "active" end
    for _, quest in ipairs(chain.members) do
        for _, other in ipairs(quest.exclusiveTo or {}) do
            if completed[other] then skipped[quest.id] = true end
        end
    end

    local function isSkipped(id)
        local status = getStatus(id)
        if status ~= "unstarted" then return false end
        if skipped[id] ~= nil then return skipped[id] end
        -- A skipped choice carries through its branch until another route can reach it.
        -- Cache false before walking the links so a cycle never proves a route was skipped.
        skipped[id] = false
        local requirements = chain.requiredOptions[id]
        if requirements then
            for _, option in ipairs(requirements) do
                if isSkipped(option.questId) then
                    local available = false
                    for _, alternative in ipairs(option.alternativeIds) do
                        if not isSkipped(alternative) then available = true end
                    end
                    if not available then
                        skipped[id] = true
                        return true
                    end
                end
            end
            return false
        end
        local parents = chain.predecessors[id]
        if not parents or #parents == 0 then return false end
        for _, parent in ipairs(parents) do
            if not isSkipped(parent) then return false end
        end
        skipped[id] = true
        return true
    end

    local endings = #chain.endings > 0 and chain.endings or chain.members
    local reachedEnding = false
    for _, quest in ipairs(endings) do
        if completed[quest.id] then
            reachedEnding = true
        elseif not isSkipped(quest.id) then
            return "active"
        end
    end
    return reachedEnding and "completed" or "active"
end

---@param index QuestIndex
---@param characterState CharacterQuestState
---@return QuestProgress
function QuestProgress.New(index, characterState)
    return setmetatable({
        index = index,
        characterState = characterState,
        isCompleted = function(id) return characterState:GetProgress(id).completed end,
    }, QuestProgress)
end

---@param id number
---@return QuestLogStatus?
function QuestProgress:GetLogStatus(id)
    local progress = self.characterState:GetProgress(id)
    if progress.active then
        return progress.ready and "ready" or "active"
    end
    if progress.completed then
        return "completed"
    end
end

---@param id number
---@param view QuestChainView?
---@param level? number
---@return QuestStatus, string?
function QuestProgress:GetStatus(id, view, level)
    local logStatus = self:GetLogStatus(id)
    if logStatus then
        return logStatus
    end
    local quest = self.index:Get(id)
    if not quest then
        return "unstarted"
    end
    level = level or self.characterState:GetLevel()
    if quest.minLevel and level and level < quest.minLevel then
        return "blocked", "Requires level " .. quest.minLevel
    end
    local group = QuestRequirements.UnmetGroup(quest, view, self.index, self.isCompleted)
    if group then
        return "blocked", unmetReasons[group]
    end
    return "unstarted"
end
