local ns = {}
assert(loadfile("ForeverQuestChain/Rewards/LocationRewardCatalog.lua"))("ForeverQuestChain", ns)

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
    [103] = { 2 },
}
local source = {
    ListItemIds = function() return { 100, 101, 102, 103 } end,
    GetQuestIdsForItem = function(_, id) return reverse[id] end,
    GetItem = function(_, id)
        if id == 100 then return { id = id, name = "Shared blade" } end
        if id == 101 then return { id = id, name = "Outside recipe" } end
        assert(id == 103, "Looked up an item without reward links")
    end,
}
local emptySource = setmetatable({
    ListItemIds = function() return {} end,
}, { __index = source })
local missingSource = setmetatable({
    ListItemIds = function() return nil end,
}, { __index = source })
assert(ns.LocationRewardCatalog.Build(missingSource) == nil)
local empty = assert(ns.LocationRewardCatalog.Build(emptySource))
assert(#empty:Search(browse, "zones", 42, "") == 0)
local catalog = assert(ns.LocationRewardCatalog.Build(source))
local dungeonItems = catalog:Search(browse, "dungeons", 17, "")
assert(#dungeonItems == 1 and dungeonItems[1].item.id == 100)
assert(#dungeonItems[1].sources == 2 and dungeonItems[1].sources[2].quest.id == 2)
local zoneItems = catalog:Search(browse, "zones", 42, "  RECIPE ")
assert(#zoneItems == 1 and zoneItems[1].item.id == 101)
assert(zoneItems[1].sources[1].destination == 1)
assert(catalog:Search(browse, "zones", 42, "100")[1].item.id == 100)
assert(#catalog:Search(browse, "zones", 42, "10") == 0)
assert(#catalog:Search(browse, "zones", 42, "missing") == 0)

local items, visited = {}, 0
for id = 1, 201 do items[id] = id end
local bulkSource = setmetatable({
    ListItemIds = function() return items end,
    GetQuestIdsForItem = function(_, id)
        visited = id
        return reverse[id]
    end,
}, { __index = source })
local yielded = 0
local bulk = ns.LocationRewardCatalog.Build(bulkSource, function()
    assert(visited == 200, "Expected to yield after 200 items")
    yielded = yielded + 1
end)
assert(yielded == 1 and visited == 201)
assert(#bulk:Search(browse, "dungeons", 17, "") == 1)
print("reward catalog tests passed")
