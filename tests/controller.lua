local ns = {}
local handlers, registered, requests = {}, {}, {}
local onEvent, callbacks, details, statuses
local completed = {}
local function noop() end
local quests = {
    [11] = { id = 11, title = "First step", successors = { 12 }, allOf = {}, anyOf = {} },
    [12] = { id = 12, title = "Next step", allOf = {}, anyOf = {} },
}

SlashCmdList = {}
C_Timer = { After = noop }
C_QuestLog = {
    IsOnQuest = noop,
    ReadyForTurnIn = noop,
    IsQuestFlaggedCompleted = function(id) return completed[id] end,
    RequestLoadQuestByID = function(id) requests[#requests + 1] = id end,
}
Menu = { ModifyMenu = function(name, handler) handlers[name] = handler end }
function CreateFrame()
    return {
        RegisterEvent = function(_, name) registered[name] = true end,
        SetScript = function(_, script, handler)
            assert(script == "OnEvent")
            onEvent = handler
        end,
    }
end
function UnitLevel() return 30 end
function HaveQuestRewardData() return false end
function GetQuestLogRewardXP(id) return id * 10 end
function GetQuestLogRewardMoney() return 0 end
function GetNumQuestLogChoices() return 0 end
function GetNumQuestLogRewards() return 0 end

ns.QuestData = { New = function()
    return {
        ids = function() return { 11, 12 } end,
        read = function(id) return quests[id] end,
        characterFilter = noop,
        classes = function() return {} end,
        dungeon = noop,
        pickupZones = function() return {} end,
    }
end }
ns.Window = { New = function(actions)
    callbacks = actions
    return {
        ShowJournal = noop,
        OpenQuestPage = noop,
        IsActiveChainsOpen = noop,
        timeline = { Render = function(_, _, _, progress) statuses = progress end },
        questDetails = { Render = function(_, quest, rewards)
            details = { id = quest.id, xp = rewards.xp }
        end },
    }
end }

for _, module in ipairs({ "Chain", "Rewards", "ForeverQuests", "QuestLog", "Controller", "Core" }) do
    assert(loadfile("ForeverQuestChain/" .. module .. ".lua"))("ForeverQuestChain", ns)
end

local function emit(event, ...)
    assert(registered[event], "Missing event: " .. event)
    onEvent(nil, event, ...)
end

assert(SLASH_FOREVERQUESTCHAIN1 == "/questchain" and callbacks == nil)
handlers.MENU_QUEST_MAP_LOG_TITLE({ questID = 11 }, {
    CreateButton = function(_, _, click) click() end,
})
assert(details.id == 11 and details.xp.state == "loading" and requests[1] == 11)

callbacks.selectStep(12)
assert(details.id == 12 and details.xp.state == "loading" and requests[2] == 12)
emit("QUEST_DATA_LOAD_RESULT", 11, true)
assert(details.id == 12 and details.xp.state == "loading")
emit("QUEST_DATA_LOAD_RESULT", 12, true)
assert(details.id == 12 and details.xp.value == 120)

completed[12] = true
emit("QUEST_TURNED_IN", 12)
assert(statuses[12].status == "completed" and requests[3] == 12)
