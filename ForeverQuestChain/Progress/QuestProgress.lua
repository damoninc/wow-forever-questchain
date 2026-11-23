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
