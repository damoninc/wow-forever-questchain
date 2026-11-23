local ns = {}
local requested, ready, requestQuestId, choiceCount

function HaveQuestRewardData() return ready end
function GetQuestLogRewardXP() return 120 end
function GetQuestLogRewardMoney() return 0 end
function GetNumQuestLogRewards() return 1 end
function GetNumQuestLogChoices() return choiceCount or 0 end
function GetQuestLogRewardInfo(index, questId)
    assert(index == 1 and questId == 42)
    return nil, 134400, 2, nil, nil, 123
end
function GetQuestLogChoiceInfo(index, questId)
    assert(index == 1 and questId == 42)
    return "Choice item", 134401, 1, nil, nil, 124
end
C_Item = { RequestLoadItemDataByID = function(itemId) requested = itemId end }
C_QuestLog = {
    RequestLoadQuestByID = function(id) requestQuestId = id end,
    IsOnQuest = function(id) if id == 42 or id == 45 then return true end end,
    ReadyForTurnIn = function(id) if id == 42 then return true end end,
    IsQuestFlaggedCompleted = function(id) if id == 42 then return true end end,
    GetNumQuestLogEntries = function() return 9 end,
    GetInfo = function(index)
        return ({
            { isHeader = true, title = "First zone" },
            { questID = 42, level = 15 },
            { questID = 43, isHidden = true, level = 16 },
            { questID = 44, isTask = true, level = 16 },
            { isHeader = true, title = "Second zone" },
            { questID = 45, isBounty = true, level = 16 },
            { questID = 46, isBounty = true, level = 17 },
            { questID = 47, level = 0 },
        })[index]
    end,
    IsComplete = function(id) return id == 46 end,
    GetLogIndexForQuestID = function(id) return id == 42 and 2 or 0 end,
    GetQuestObjectives = function(id)
        assert(id == 42)
        return { { text = "Gather the materials", finished = true } }
    end,
    IsUnitOnQuest = function(unit, id) return id == 42 and unit ~= "party4" end,
}

function UnitRace() return "Human", "Human", 1 end
function UnitFactionGroup() return "Alliance" end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function UnitLevel() return 22 end
function GetQuestLogQuestText(index)
    assert(index == 2)
    return "Quest description", "Quest objective"
end
function GetNumSubgroupMembers() return 4 end
function UnitIsConnected(unit) return unit ~= "party3" end
function UnitName(unit)
    if unit == "party1" then return "Alice", "" end
    if unit == "party2" then return "Bob", "OtherRealm" end
    error("Asked for a party member who should be filtered out")
end

assert(loadfile("ForeverQuestChain/Adapters/Forever/ForeverCharacterQuestState.lua"))("ForeverQuestChain", ns)
local character = ns.ForeverCharacterQuestState.New()
local identity = character:GetIdentity()
assert(identity.raceId == 1 and identity.faction == "Alliance" and identity.classToken == "WARRIOR")
assert(character:GetLevel() == 22)
local progress = character:GetProgress(42)
assert(progress.active and progress.ready and progress.completed)
local absent = character:GetProgress(99)
assert(absent.active == false and absent.ready == false and absent.completed == false)
local logged = character:ListLoggedQuests()
assert(logged[42].level == 15 and logged[42].zone == "First zone")
assert(not logged[43] and not logged[44] and not logged[45])
assert(logged[46].level == 17 and logged[46].zone == "Second zone")
assert(logged[47].level == nil and logged[47].zone == "Second zone")
local details = character:GetLogDetails(42)
assert(details.description == "Quest description" and details.objectiveText == "Quest objective")
assert(details.progress[1].finished and character:GetLogDetails(99) == nil)
local members = character:GetPartyMembersOnQuest(42)
assert(#members == 2 and members[1] == "Alice" and members[2] == "Bob-OtherRealm")
assert(character:GetPartyMembersOnQuest(99) == nil)

C_Map = {
    GetMapInfo = function(id)
        return id == 2 and { name = "Locust Valley", parentMapID = 1, mapType = 3 } or nil
    end,
    GetMapLevels = function(id)
        if id == 2 then return 15, 20 end
        if id == 3 then return 12, 10 end
        if id == 4 then return 0, 20 end
    end,
    GetBestMapForUnit = function(unit)
        assert(unit == "player")
        return 2
    end,
}
assert(loadfile("ForeverQuestChain/Adapters/Forever/ForeverMapMetadata.lua"))("ForeverQuestChain", ns)
local maps = ns.ForeverMapMetadata.New()
local map = maps:GetMap(2)
assert(map.name == "Locust Valley" and map.parentMapId == 1 and map.mapType == 3)
assert(maps:GetMap(99) == nil and maps:GetMap(nil) == nil)
local low, high = maps:GetLevelRange(2)
assert(low == 15 and high == 20)
low, high = maps:GetLevelRange(3)
assert(low == 12 and high == 12)
assert(maps:GetLevelRange(4) == nil and maps:GetLevelRange(nil) == nil)
assert(maps:GetPlayerMapId() == 2)
C_Map.GetMapLevels = nil
assert(maps:GetLevelRange(2) == nil)

assert(loadfile("ForeverQuestChain/Adapters/Forever/ForeverQuestRewardGateway.lua"))("ForeverQuestChain", ns)
local gateway = ns.ForeverQuestRewardGateway.New()

gateway:Request(42)
assert(requestQuestId == 42)
assert(gateway:Read(42, false) == nil)
local partial = gateway:Read(42, true)
assert(partial.xp.state == "known" and partial.xp.value == 120)
assert(partial.copper.state == "unavailable")
assert(partial.choices.state == "unavailable")
assert(partial.guaranteed.value[1].quantity == 2 and requested == 123)

ready = true
local confirmed = gateway:Read(42, false)
assert(confirmed.copper.state == "known" and confirmed.copper.value == 0)
assert(confirmed.choices.state == "known" and #confirmed.choices.value == 0)

choiceCount = 1
local both = gateway:Read(42, false)
assert(both.guaranteed.value[1].id == 123)
assert(both.choices.value[1].id == 124 and both.choices.value[1].name == "Choice item")
print("Forever adapter tests passed")
