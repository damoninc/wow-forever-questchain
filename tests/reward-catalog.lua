local ns = {}
assert(loadfile("ForeverQuestChain/RewardCatalog.lua"))("ForeverQuestChain", ns)

local quests = {
    [1] = { id = 1, title = "First quest" },
    [2] = { id = 2, title = "Second quest" },
    [3] = { id = 3, title = "Outside quest" },
}
local dungeon = { key = 17, name = "Dungeon" }
local otherDungeon = { key = 18, name = "Other dungeon" }
local browse = {
    Groups = function(_, kind)
        return { { steps = {
            { quest = quests[1], dungeon = dungeon },
            { quest = quests[2], dungeon = dungeon },
            { quest = quests[3], dungeon = kind == "dungeons" and otherDungeon or nil, destination = 1 },
        } } }
    end,
}
local reverse = {
    [100] = { 1, 2, 2, 999 },
    [101] = { 3 },
    [102] = {},
}
local source = {
    itemIds = function() return { 100, 101, 102 } end,
    rewardQuests = function(id) return reverse[id] end,
    rewardItem = function(id) return { id = id, name = id == 100 and "Shared blade" or "Outside recipe" } end,
}
assert(ns.RewardCatalog.Build({}) == nil)
local catalog = assert(ns.RewardCatalog.Build(source))
local dungeonItems = catalog:Search(browse, "dungeons", 17, "")
assert(#dungeonItems == 1 and dungeonItems[1].item.id == 100)
assert(#dungeonItems[1].sources == 2 and dungeonItems[1].sources[2].quest.id == 2)
local zoneItems = catalog:Search(browse, "zones", 42, "  RECIPE ")
assert(#zoneItems == 1 and zoneItems[1].item.id == 101)
assert(zoneItems[1].sources[1].destination == 1)
assert(catalog:Search(browse, "zones", 42, "100")[1].item.id == 100)
assert(#catalog:Search(browse, "zones", 42, "10") == 0)
assert(#catalog:Search(browse, "zones", 42, "missing") == 0)
print("reward catalog tests passed")
