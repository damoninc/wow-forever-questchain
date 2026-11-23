local ns = {}
local handlers, registered, requests = {}, {}, {}
local onEvent, callbacks, details, statuses, results
local runTimers, showOutliers
local timers, catalogReads, starterReads = {}, 0, 0
local completed = {}
local function noop() end
local quests = {
    [11] = { name = "First step", nextQuestInChain = 12 },
    [12] = { name = "Next step", preQuestSingle = { 11 } },
}

SlashCmdList = {}
C_Timer = { After = function(_, callback)
    if runTimers then callback() else timers[#timers + 1] = callback end
end }
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
function IsLoggedIn() return false end
function HaveQuestRewardData() return false end
function GetQuestLogRewardXP(id) return id * 10 end
function GetQuestLogRewardMoney() return 0 end
function GetNumQuestLogChoices() return 0 end
function GetNumQuestLogRewards() return 1 end
function GetQuestLogRewardInfo(_, questId) return "Reward", 1, 1, nil, nil, 100 + questId end

LibQuestieDB = {
    RequireContract = function(version) return version == 1 end,
    Quest = {
        GetAllIds = function()
            catalogReads = catalogReads + 1
            return { 11, 12 }
        end,
        Exists = function(id) return quests[id] ~= nil end,
        GetAll = function(id, keys)
            local fields = {}
            for index, key in ipairs(keys) do
                if key == "startedBy" then starterReads = starterReads + 1 end
                fields[index] = quests[id][key]
            end
            return fields
        end,
    },
}
ns.Window = { New = function(actions)
    callbacks = actions
    return {
        ShowJournal = noop,
        OpenQuestPage = noop,
        IsActiveChainsOpen = noop,
        Route = function() return { page = "quests" } end,
        RefreshNavigation = noop,
        questList = {
            ShowResults = function(_, questsFound) results = questsFound end,
            Offset = function() return 0 end,
            SetBrowseMode = noop,
            SetBrowseCategories = noop,
            SetCompletedFilter = noop,
            SetShowOutliers = function(_, shown) showOutliers = shown == true end,
            ShowBrowse = noop,
        },
        timeline = { Render = function(_, _, _, progress) statuses = progress end },
        questDetails = { Render = function(_, quest, rewards, requirements)
            details = { id = quest.id, xp = rewards.xp, requirements = requirements }
        end },
    }
end }

-- Load the real composition order with a fake window and no game frames.
for entry in io.lines("ForeverQuestChain/ForeverQuestChain.toc") do
    local file = entry:match("^%s*(.-)%s*$"):gsub("\\", "/")
    if file:match("%.lua$") and (not file:match("^UI/")
        or file == "UI/Journal/JournalController.lua" or file == "UI/QuestLog/QuestLog.lua"
        or file == "UI/Journal/Chain/QuestRequirementsText.lua") then
        assert(loadfile("ForeverQuestChain/" .. file))("ForeverQuestChain", ns)
    end
end

local function emit(event, ...)
    assert(registered[event], "Missing event: " .. event)
    onEvent(nil, event, ...)
end

assert(SLASH_FOREVERQUESTCHAIN1 == "/questchain" and callbacks == nil)
assert(catalogReads == 0 and #timers == 0, "Wait for the player identity before scheduling the catalog")
emit("PLAYER_LOGIN")
emit("PLAYER_LOGIN")
assert(#timers == 1 and catalogReads == 0, "Login queues one background build")
table.remove(timers, 1)()
assert(catalogReads == 1 and starterReads == 2 and callbacks == nil,
    "Build the quest and location indexes before creating the journal window")
handlers.MENU_QUEST_MAP_LOG_TITLE({ questID = 11 }, {
    CreateButton = function(_, _, click) click() end,
})
assert(details.id == 11 and details.xp.state == "loading" and requests[1] == 11)

callbacks.selectStep(12)
assert(details.id == 12 and details.xp.state == "loading" and requests[2] == 12)
assert(details.requirements == "Complete one prerequisite\nAny one required  /  First step")
emit("QUEST_DATA_LOAD_RESULT", 11, true)
assert(details.id == 12 and details.xp.state == "loading")
emit("QUEST_DATA_LOAD_RESULT", 12, true)
assert(details.id == 12 and details.xp.value == 120)
local currentDetails = details
emit("GET_ITEM_INFO_RECEIVED", 111, true)
assert(details == currentDetails, "A late item reply for quest 11 must leave the selected details alone")
emit("GET_ITEM_INFO_RECEIVED", 112, true)
assert(details ~= currentDetails and details.id == 12, "The selected reward item can refresh quest 12")

completed[12] = true
emit("QUEST_TURNED_IN", 12)
assert(statuses[12].status == "completed" and requests[3] == 12)

callbacks.search("11")
assert(#results == 1 and results[1].id == 11)
assert(details.id == 11 and details.xp.value == 110)

runTimers = true
local zoneRoute = { page = "quests", kind = "zones", key = 0 }
local dungeonRoute = { page = "quests", kind = "dungeons", key = 1584 }
callbacks.openJournalRoute(zoneRoute)
assert(not showOutliers, "Outliers are hidden when first opening zone quests")
callbacks.setShowOutliers(true)
callbacks.openJournalRoute(dungeonRoute)
assert(not showOutliers, "The zone toggle should not change the dungeon toggle")
callbacks.openJournalRoute(zoneRoute)
assert(showOutliers, "Return to the zone with its outlier preference intact")
assert(catalogReads == 1, "Browsing reuses the startup index")
