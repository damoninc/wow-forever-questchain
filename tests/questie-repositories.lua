local ns = {}
for _, module in ipairs({
    "QuestieLocationLookup", "QuestieQuestRepository", "QuestieQuestLocationRepository",
    "QuestieRewardSourceRepository",
}) do
    local load = loadfile("ForeverQuestChain/Adapters/QuestieDB/" .. module .. ".lua")
    assert(load, "Missing QuestieDB adapter: " .. module)
    load("ForeverQuestChain", ns)
end

local raceBit = 2 ^ 33
local records = {
    [1] = {
        name = "The road ahead", requiredLevel = 10, questLevel = 12, zoneOrSort = 108,
        preQuestSingle = { 2 }, preQuestGroup = { -3, 4 }, exclusiveTo = { -5 },
        childQuests = { 6 }, nextQuestInChain = 7, breadcrumbs = { 8 },
        breadcrumbForQuestId = 9, parentQuest = 10, requiredRaces = raceBit,
        objectivesText = { "Find the door" }, startedBy = { { 11, 12 }, { 41 } },
        finishedBy = { { 12 } },
    },
    [2] = { zoneOrSort = 10029, requiredRaces = 0 },
    [3] = { zoneOrSort = 10001 },
    [4] = { zoneOrSort = 771 },
    [5] = { zoneOrSort = 2717 },
    [6] = { zoneOrSort = -161, requiredClasses = 1 },
    [7] = { requiredClasses = 129 },
    [8] = { requiredClasses = 131, zoneOrSort = 2519 },
}

local questIds, readCounts, spawnCalls = { 1, 2, 3, 4, 5, 6, 7, 8 }, {}, 0
local function getFields(id, keys)
    local record = records[id]
    if not record then return nil end
    local result = { n = #keys }
    for index, key in ipairs(keys) do
        readCounts[key] = (readCounts[key] or 0) + 1
        result[index] = record[key]
    end
    return result
end

local itemIds = { 30, 31, 32 }
local lib = {
    RequireContract = function(version) return version == 1 end,
    Enum = {
        classKeys = { WARRIOR = 1, PALADIN = 2, MAGE = 128, ALL_CLASSES = 131 },
        raceMaskById = { [1] = 1, [95] = raceBit },
        factionRaceMasks = { Alliance = raceBit + 1, Horde = 2 },
    },
    Quest = {
        Exists = function(id) return records[id] ~= nil end,
        GetAllIds = function() return questIds end,
        GetAll = getFields,
    },
    Support = {
        Get = function(name)
            assert(name == "ZoneDB")
            return { private = {
                areaIdToUiMapId = { [108] = 99, [40] = 2, [50] = 3, [1581] = 31, [2519] = 73 },
                areaIdToUiMapIdOverride = "return {\n    [108] = 4,\n}",
                subZoneToParentZone = { [108] = 30 },
                subZoneToParentZoneOverride = { [108] = 40, [771] = 1581 },
                dungeons = {
                    [1581] = { "Deadmines", { 10029 } }, [2717] = { "Molten Core" },
                },
            } }
        end,
    },
    Npc = {
        name = function(id) return ({ [11] = "Scout", [12] = "Guard" })[id] end,
        spawns = function(id)
            spawnCalls = spawnCalls + 1
            return ({ [11] = { [108] = { { 10, 40 } } },
                [12] = { [40] = { { 25, 20 } }, [50] = { { 16, 90 } } } })[id]
        end,
    },
    Object = {
        name = function() return "Notice board" end,
        spawns = function() return { [40] = { { 25, 20 } } } end,
    },
    Item = {
        GetAllIds = function() return itemIds end,
        Exists = function(id) return id == 30 or id == 31 or id == 32 end,
        questRewards = function(id) return id == 30 and { 1, 2 } or nil end,
        name = function(id) return id == 30 and "Reward" or nil end,
        requiredLevel = function(id) return id == 30 and 20 or 0 end,
    },
}

local maps = {
    [2] = { name = "Westfall", mapType = 3 }, [3] = { name = "Lakeshire", mapType = 3 },
    [4] = { name = "Moonbrook", parentMapId = 2 }, [31] = { name = "Deadmines" },
}
local mapMetadata = { GetMap = function(_, id) return maps[id] end }

local questAdapter = ns.QuestieQuestRepository
assert(questAdapter.CheckContract(lib))
local supported, errorMessage = questAdapter.CheckContract(nil)
assert(not supported and errorMessage == "Enable the Forever version of QuestieDB.")
supported, errorMessage = questAdapter.CheckContract({ RequireContract = function() return false end })
assert(not supported and errorMessage == "Update QuestieDB to a compatible version.")
supported, errorMessage = questAdapter.CheckContract({ RequireContract = function() return false, "Too old" end })
assert(not supported and errorMessage == "Too old")

local lookup = ns.QuestieLocationLookup.New(lib, mapMetadata)
local quests = questAdapter.New(lib, lookup)
local locations = ns.QuestieQuestLocationRepository.New(lib, lookup)
assert(#quests:ListIds() == 8 and quests:GetSummary(999) == nil and quests:GetDetails(999) == nil)

local summary = quests:GetSummary(1)
assert(summary.title == "The road ahead" and summary.level == 12 and summary.minLevel == 10)
assert(summary.zone == "Moonbrook", "Use the direct area map for the quest summary")
assert(summary.objectives == nil and not readCounts.objectivesText and not readCounts.startedBy
    and not readCounts.finishedBy and spawnCalls == 0, "Summary reads leave details and spawns lazy")
assert(summary.anyOf[1] == 2 and summary.allOf[1] == -3 and summary.allOf[2] == 4)
assert(summary.exclusiveTo[1] == -5 and summary.breadcrumbs[1] == 8 and summary.breadcrumbTarget == 9)
assert(summary.parentId == 10 and summary.successors[1] == 6 and summary.successors[2] == 7)
assert(#quests:GetSummary(1).successors == 2 and #records[1].childQuests == 1,
    "Appending the next link leaves the provider's child list intact")
assert(summary.restrictions.byRaceId[95] == true and summary.restrictions.byRaceId[1] == false)
assert(summary.restrictions.byFaction.Alliance == true and summary.restrictions.byFaction.Horde == false)
assert(summary.restrictions.byRaceId[99] == nil and quests:GetSummary(2).restrictions == nil)
assert(quests:GetSummary(2).title == "Quest #2" and quests:GetSummary(2).zone == nil)

local zones = {}
for _, zone in ipairs(locations:GetPickupZones(1)) do zones[zone.key] = zone end
assert(zones[2].name == "Westfall" and zones[2].mapId == 2 and zones[3].name == "Lakeshire" and zones[4] == nil)
local recorded = locations:GetRecordedZone(1)
assert(recorded.key == 2 and recorded.name == "Westfall" and recorded.mapId == 2)
assert(locations:GetRecordedZone(8).mapId == 73 and locations:GetRecordedZone(8).name == nil)
assert(locations:GetRecordedZone(7) == nil and locations:GetRecordedZone(999) == nil)
assert(#locations:GetPickupZones(999) == 0)
local dungeon = locations:GetDungeon(2)
assert(dungeon.key == 1581 and dungeon.name == "Deadmines" and dungeon.mapId == 31)
assert(locations:GetDungeon(3).key == 2017 and locations:GetDungeon(3).name == "Stratholme")
assert(locations:GetDungeon(4).key == 1581 and locations:GetDungeon(5) == nil and locations:GetDungeon(999) == nil)
assert(locations:GetClassCategories(6)[1].key == "MAGE", "A class sort takes precedence over a class mask")
local classes = locations:GetClassCategories(7)
assert(#classes == 2 and classes[1].key == "WARRIOR" and classes[2].key == "MAGE")
assert(#locations:GetClassCategories(8) == 0 and #locations:GetClassCategories(999) == 0)

local details = quests:GetDetails(1)
assert(details.objectives[1] == "Find the door" and details.starters[1].name == "Scout")
assert(details.starters[1].zone == "Moonbrook" and details.starters[1].mapId == 4
    and details.starters[1].x == 10 and details.starters[1].y == 40)
assert(details.starters[3].name == "Notice board" and details.starters[3].mapId == 2)
assert(details.finishers[1].name == "Guard" and details.finishers[1].mapId == nil,
    "Ambiguous spawns leave the waypoint absent")
assert(readCounts.startedBy == 1 and spawnCalls == 2, "Reuse starter and spawn reads across the repositories")

local rewardAdapter = ns.QuestieRewardSourceRepository
local rewards = rewardAdapter.New(lib)
assert(#rewards:ListItemIds() == 3 and rewards:GetItem(30).name == "Reward" and rewards:GetItem(30).level == 20)
assert(rewards:GetItem(31).name == "Item #31" and rewards:GetItem(31).level == nil)
assert(rewards:GetItem(999) == nil and rewards:GetQuestIdsForItem(31) == nil)
local linked = rewards:GetQuestIdsForItem(30)
assert(#linked == 2 and linked[1] == 1 and linked[2] == 2)
local unavailable = rewardAdapter.New({ Item = { GetAllIds = function() return {} end } })
assert(unavailable:ListItemIds() == nil and unavailable:GetQuestIdsForItem(30) == nil)
local empty = rewardAdapter.New({ Item = {
    GetAllIds = function() return {} end, name = function() end, questRewards = function() end,
} })
assert(#empty:ListItemIds() == 0)

print("QuestieDB repository tests passed")
