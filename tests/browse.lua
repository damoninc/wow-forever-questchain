local ns = {}
for _, file in ipairs({
    "Quests/QuestRequirements", "Quests/QuestIndex", "Quests/QuestSearch", "Quests/QuestChain",
    "Progress/QuestProgress", "Progress/ActiveChainsQuery", "Locations/QuestLocationContext",
    "Locations/LocationQuestCatalog", "Rewards/LocationRewardCatalog", "Adapters/Forever/ForeverMapMetadata",
    "Adapters/QuestieDB/QuestieLocationLookup", "Adapters/QuestieDB/QuestieQuestRepository",
    "Adapters/QuestieDB/ForeverDungeonAssignments",
    "Adapters/QuestieDB/QuestieQuestLocationRepository", "Adapters/QuestieDB/QuestieRewardSourceRepository",
}) do
    assert(loadfile("ForeverQuestChain/" .. file .. ".lua"))("ForeverQuestChain", ns)
end

local function quest(name, fields)
    fields = fields or {}
    fields.name = name
    return fields
end

local records = {
    [1] = quest("The Plot", { startedBy = { { 11 } }, nextQuestInChain = 2 }),
    [2] = quest("A Lead", { startedBy = { { 12, 13 } }, nextQuestInChain = 3, zoneOrSort = 10029 }),
    [3] = quest("The Finale", { startedBy = { { 11 } }, zoneOrSort = 1581, preQuestSingle = { 2 } }),
    [4] = quest("The Plot", { startedBy = { { 11 } }, zoneOrSort = 2717 }),
    [5] = quest("An Invitation", { startedBy = { { 12 } }, breadcrumbForQuestId = 2, nextQuestInChain = 2 }),
    [6] = quest("A Shared Lead", { startedBy = { { 12 } } }),
    [7] = quest("Class Lesson", { startedBy = { [3] = { 99 } }, zoneOrSort = -161 }),
    [8] = quest("Class Training", { requiredClasses = 129 }),
    [9] = quest("General Training", { requiredClasses = 131 }),
}
records[1].breadcrumbs, records[4].breadcrumbs = { 6 }, { 6 }
records[1].questLevel, records[3].questLevel = 30, 20
local skyborneAlliance, skyborneHorde = 2 ^ 32, 2 ^ 33
records[1].requiredRaces = 0
records[2].requiredRaces = 77 + skyborneAlliance
records[4].requiredRaces = 178 + skyborneHorde
records[7].requiredRaces = skyborneAlliance
for id = 10, 94 do
    records[id] = quest("Local errand " .. id, { startedBy = { { 11 } } })
end
records[10].questLevel, records[11].questLevel = 25, 5
records[94].questLevel, records[94].zoneOrSort = 10, 717
records[20].questLevel, records[20].nextQuestInChain, records[21].questLevel = 40, 21, 45
records[95] = quest("Temple Preparation", { nextQuestInChain = 96 })
records[96] = quest("Dungeon Reagent", { zoneOrSort = -161, objectives = { [3] = { { 500 } } } })
records[97] = quest("Reagent Found in Two Regions", { objectives = { [3] = { { 501 } } } })
records[98] = quest("Optional Route A", { startedBy = { { 11 } }, questLevel = 50 })
records[99] = quest("Optional Route B", { startedBy = { { 11 } }, questLevel = 50 })
records[100] = quest("Shared Conclusion", { startedBy = { { 12 } }, preQuestSingle = { 98, 99 } })
records[101] = quest("Fork Start", { childQuests = { 102, 103 } })
records[102] = quest("First Ending")
records[103] = quest("Second Ending")
records[104] = quest("Choose an Ending", { childQuests = { 105, 106 } })
records[105] = quest("First Choice", { exclusiveTo = { 106 } })
records[106] = quest("Second Choice")
records[107] = quest("Partial Chain", { nextQuestInChain = 108 })
records[108] = quest("Known Step", { nextQuestInChain = 9999 })
records[109] = quest("Choose a Route", { childQuests = { 110, 111 } })
records[110] = quest("First Route", { exclusiveTo = { 111 }, nextQuestInChain = 112 })
records[111] = quest("Second Route", { nextQuestInChain = 113 })
records[112] = quest("First Route Conclusion")
records[113] = quest("Second Route Conclusion")
records[114] = quest("Buy a Reagent", { objectives = { [3] = { { 502 } } } })
records[115] = quest("Craft a Reagent", { objectives = { [3] = { { 503 } } } })
records[116] = quest("Choose a Branch", { childQuests = { 117, 118 } })
records[117] = quest("First Branch", { exclusiveTo = { 118 } })
records[118] = quest("Second Branch")
records[119] = quest("Shared Prerequisite")
records[120] = quest("Second Branch Conclusion", { preQuestGroup = { -118, 119 } })

C_Map = {
    GetMapInfo = function(id)
        return ({ [1] = { name = "Stormwind" }, [2] = { name = "Westfall" },
            [3] = { name = "Moonbrook", parentMapID = 2 } })[id]
    end,
    GetMapLevels = function(id)
        if id == 1 then return 20, 30 end
        if id == 2 then return 10, 19 end
    end,
}

local spawnCalls = 0
local questie = {
    RequireContract = function() return true end,
    Enum = {
        sortKeys = { MAGE = -161 },
        itemClasses = { QUEST = 12 },
        classKeys = { WARRIOR = 1, PALADIN = 2, MAGE = 128, ALL_CLASSES = 131 },
        raceMaskById = { [1] = 1, [2] = 2, [95] = skyborneAlliance, [96] = skyborneHorde },
        factionRaceMasks = { Alliance = 77 + skyborneAlliance, Horde = 178 + skyborneHorde },
    },
    Quest = {
        GetAllIds = function()
            local ids = {}
            for id = 1, #records do ids[id] = id end
            return ids
        end,
        Exists = function(id) return records[id] ~= nil end,
        GetAll = function(id, keys)
            local result = {}
            for i, key in ipairs(keys) do result[i] = records[id][key] end
            return result
        end,
    },
    Item = {
        GetAllIds = function() return { 100, 101 } end,
        questRewards = function(id) return id == 100 and { 2, 3 } or { 2 } end,
        name = function(id) return "Reward " .. id end,
        class = function(id) return ({ [500] = 15, [501] = 12, [502] = 12, [503] = 0 })[id] end,
        flags = function(id) return id == 500 and 2048 or 0 end,
        vendors = function(id) return id == 502 and { 111 } or nil end,
    },
    Npc = { spawns = function(id)
        if id < 100 then spawnCalls = spawnCalls + 1 end
        return ({ [11] = { [1519] = {{1, 1}} }, [12] = { [40] = {{1, 1}} },
            [13] = { [108] = {{1, 1}}, [1519] = {{1, 1}} },
            [110] = { [1477] = {{-1, -1}} }, [111] = { [1519] = {{1, 1}} } })[id]
    end },
    Support = { Get = function(module)
        if module == "QuestieClassicItemDrops" then
            return { wowheadData = [[return {
                [500] = {[110] = 5}, [501] = {[110] = 5, [111] = 5},
                [502] = {[110] = 5}, [503] = {[110] = 5},
            }]] }
        end
        return { private = {
            areaIdToUiMapId = { [1519] = 1, [40] = 2, [108] = 3 },
            subZoneToParentZone = { [108] = 40 },
            dungeons = { [1581] = { "The Deadmines", { 10029 } }, [2717] = { "Molten Core" } },
        } }
    end },
}

local maps = ns.ForeverMapMetadata.New()
local lookup = ns.QuestieLocationLookup.New(questie, maps)
local quests = ns.QuestieQuestRepository.New(questie, lookup)
local locations = ns.QuestieQuestLocationRepository.New(questie, lookup)
local rewards = ns.QuestieRewardSourceRepository.New(questie)
local unknownCharacter = { GetIdentity = function() return {} end }
local index = ns.QuestIndex.New(quests, unknownCharacter)
local model = ns.QuestSearch.New(index)
local work = coroutine.create(function()
    return ns.LocationQuestCatalog.Build(index, locations, maps, coroutine.yield)
end)
assert(coroutine.resume(work))
assert(coroutine.status(work) == "suspended" and spawnCalls == 0)
assert(model:Search("A Lead")[1].id == 2)
local search = model:Search("Local errand")
assert(search[1].id == 11 and search[2].id == 94 and search[3].id == 10 and search[6].id == 12)
local browse
while coroutine.status(work) ~= "dead" do
    local ok, result = coroutine.resume(work)
    assert(ok, result)
    browse = result
end
assert(not locations:GetDungeon(95) and not locations:GetDungeon(97),
    "Pickup or an ambiguous item source cannot assign a quest to a dungeon")
assert(not locations:GetDungeon(114) and not locations:GetDungeon(115),
    "Incidental drops cannot assign vendor or crafted items to a dungeon")
local temple = browse:Groups("dungeons", 1477)[1]
assert(temple and #temple.steps == 2 and temple.steps[1].quest.id == 95
    and temple.steps[2].quest.id == 96 and temple.steps[2].dungeon.key == 1477,
    "A dungeon-only objective source should anchor its whole chain")
local function groupWith(groups, key)
    for _, group in ipairs(groups) do
        if group.key == key then return group end
    end
end
local stormwind = browse:Groups("zones", 1)
local westfall = browse:Groups("zones", 2)
local stormwindPlot, westfallPlot = groupWith(stormwind, 1), groupWith(westfall, 1)
assert(#stormwind > 80 and #stormwindPlot.steps == 3)
assert(stormwind[1].key == 11 and stormwind[2].key == 94 and stormwind[3].key == 1 and stormwind[4].key == 10)
assert(stormwindPlot.level == 20 and stormwindPlot.steps[1].quest.id == 1)
assert(#westfallPlot.steps == 2 and westfallPlot.steps[1].quest.id == 5)
assert(westfallPlot.steps[1].destination == 2 and westfallPlot.steps[2].quest.id == 2)
assert(groupWith(westfall, 6).steps[1].quest.id == 6)
assert(groupWith(stormwind, 4).title == stormwindPlot.title)
assert(browse:MatchZone(3).key == 2)
assert(spawnCalls == 3)

local dungeonGroups = browse:Groups("dungeons", 1581)
assert(#dungeonGroups == 1 and #dungeonGroups[1].steps == 4)
local dungeonSteps = {}
for _, step in ipairs(dungeonGroups[1].steps) do dungeonSteps[step.quest.id] = step end
assert(dungeonSteps[1] and not dungeonSteps[1].dungeon)
assert(dungeonSteps[2].dungeon.key == 1581 and dungeonSteps[3].dungeon.key == 1581)
assert(dungeonSteps[5].destination == 2 and not dungeonSteps[6])
assert(#browse:Groups("dungeons", 717) == 1 and browse:Groups("dungeons", 717)[1].standalone)
assert(#browse:Groups("dungeons", 2717) == 0)
local zonesByLevel = browse:Categories("zones")
assert(zonesByLevel[1].key == 2 and zonesByLevel[1].minLevel == 10 and zonesByLevel[1].maxLevel == 19)
local dungeonsByLevel = browse:Categories("dungeons")
assert(dungeonsByLevel[1].key == 717 and dungeonsByLevel[1].minLevel == 10)
assert(dungeonsByLevel[2].key == 1581 and dungeonsByLevel[2].minLevel == 20 and dungeonsByLevel[2].maxLevel == 20)
assert(#browse:Groups("classes", "MAGE") == 3)
assert(#browse:Groups("classes", "WARRIOR") == 1)
assert(#browse:Groups("classes", "PALADIN") == 0)

local function questStatus(id)
    return ({ [1] = "completed", [2] = "active", [3] = "ready" })[id]
end
local rows = browse:Rows("zones", 1, nil, questStatus)
local last, page, count = ns.LocationQuestCatalog.Page(rows, 999)
assert(count >= 3 and page == count and #last > 0)
assert(#rows == #stormwind)
assert(rows[1].group.key == 1 and rows[1].step.quest.id == 3 and rows[1].status == "active" and rows[1].completed == 1)
assert(rows[2].group.key == 20)
assert(rows[3].group.key == 98 and rows[4].group.key == 11 and rows[5].group.key == 94)
for index = 4, #rows do assert(rows[index].group.standalone) end
local completed = browse:Rows("zones", 1, "completed", questStatus)
assert(#completed == 1 and completed[1].group.key == 1 and completed[1].step.quest.id == 1)
assert(completed[1].status == "active")
local allComplete = browse:Rows("zones", 2, nil, function() return "completed" end)
assert(#allComplete == 3 and allComplete[1].status == "completed")
local function rowFor(kind, key, chainKey, filter, statuses)
    for _, row in ipairs(browse:Rows(kind, key, filter, function(id) return statuses[id] end)) do
        if row.group.key == chainKey then return row end
    end
end
local finishedPlot = rowFor("dungeons", 1581, 1, nil, { [1] = "completed", [2] = "completed", [3] = "completed" })
assert(finishedPlot.status == "completed" and finishedPlot.step.quest.id == 3,
    "A skipped breadcrumb should not keep a finished chain open or become its selected step")
assert(not rowFor("dungeons", 1581, 1, "incomplete", { [3] = "completed" }))
local route = rowFor("zones", 1, 98, nil, { [98] = "completed", [100] = "completed" })
assert(route.status == "completed", "A conclusion in another zone closes an any-one route")
local ongoing = rowFor("zones", 2, 98, nil, { [98] = "completed" })
assert(ongoing.status == "active", "Progress should include steps in other zones")
assert(rowFor("zones", 0, 101, nil, { [102] = "completed" }).status == "active",
    "One ending does not close an independent unfinished branch")
assert(rowFor("zones", 0, 104, nil, { [106] = "completed" }).status == "completed",
    "A completed ending can close an explicitly exclusive route")
assert(rowFor("zones", 0, 107, nil, { [108] = "completed" }).status == "active",
    "A recorded missing successor prevents treating the last known step as the conclusion")
assert(rowFor("zones", 0, 109, nil, { [110] = "completed", [112] = "completed" }).status == "completed",
    "An exclusive route stays optional through its later steps")
assert(rowFor("zones", 0, 109, nil, { [110] = "completed" }).status == "active",
    "Choosing a route does not complete its conclusion")
assert(rowFor("zones", 0, 116, nil, { [117] = "completed", [119] = "completed" }).status == "completed",
    "A shared prerequisite cannot reopen an excluded all-required route")

local activeChains = ns.ActiveChainsQuery.Rows(browse, {
    [2] = { status = "active", zone = "Westfall" },
    [3] = { status = "ready", zone = "Stormwind" },
    [4] = { status = "active" },
    [5] = { status = "active" },
    [6] = { status = "active" },
    [21] = { status = "active" },
    [999] = { status = "active" },
})
assert(#activeChains == 2, "Only verified chains with a logged step should appear")
assert(activeChains[1].title == "The Plot" and activeChains[1].count == 3,
    "Cross-zone steps and a unique optional lead-in should share one row")
assert(activeChains[1].step.quest.id == 3 and activeChains[1].log.zone == "Stormwind",
    "Open the ready-to-turn-in step ahead of other active steps")
assert(activeChains[2].step.quest.id == 21, "An active later step is enough to include a chain")
local optionalChain = ns.ActiveChainsQuery.Rows(browse, { [2] = { status = "active" }, [5] = { status = "active" } })[1]
assert(optionalChain.step.quest.id == 5 and optionalChain.step.destination == 2,
    "Open the first active step when statuses tie and preserve the optional destination")

local activeGroups, activeCount = ns.ActiveChainsQuery.Group(browse, {
    [2] = { status = "active", zone = "Westfall" },
    [3] = { status = "ready", zone = "Stormwind" },
    [21] = { status = "active", zone = "Stormwind" },
})
assert(activeCount == 2 and #activeGroups == 2, "Count distinct active chains across location sections")
assert(activeGroups[2].kind == "dungeons" and activeGroups[2].category.key == 1581,
    "Prefer a verified dungeon over pickup zones")
assert(#activeGroups[2].rows == 1 and activeGroups[2].rows[1].key == 1
    and activeGroups[2].rows[1].step.quest.id == 3,
    "Group a dungeon chain once and keep the ready-to-turn-in step selected")
assert(activeGroups[1].kind == "zones" and activeGroups[1].category.key == 1
    and activeGroups[1].rows[1].key == 20,
    "Group other chains by active pickup zone and sort equal-level sections by name")
local preparation = ns.ActiveChainsQuery.Group(browse, { [5] = { status = "active", zone = "Westfall" } })
assert(#preparation == 1 and preparation[1].category.key == 1581
    and preparation[1].rows[1].step.destination == 2,
    "A preparation step belongs under its chain's dungeon before the dungeon quest is accepted")
local noActive, noActiveCount = ns.ActiveChainsQuery.Group(browse, { [999] = { status = "active" } })
assert(#noActive == 0 and noActiveCount == 0, "Unknown quests must not invent location groups")

local view = ns.QuestChain.New(index):Build(5, nil, westfallPlot.steps[1].destination)
assert(view.focusId == 5 and #view.quests == 5)
assert(#ns.QuestChain.New(index):Build(5).quests == 5,
    "Opening a breadcrumb directly should still show the chain when it has one destination")
assert(#ns.QuestChain.New(index):Build(6).quests == 3,
    "Opening a shared breadcrumb should not combine separate chains")

local function forCharacter(raceId, faction)
    local character = { GetIdentity = function() return { raceId = raceId, faction = faction } end }
    return ns.QuestIndex.New(quests, character)
end
local alliance = forCharacter(95, "Alliance")
local horde = forCharacter(96, "Horde")
local human = forCharacter(1, "Alliance")
local plots = ns.QuestSearch.New(alliance):Search("The Plot")
assert(#plots == 1 and plots[1].id == 1)
assert(#ns.QuestSearch.New(horde):Search("The Plot") == 2)
assert(#ns.QuestSearch.New(horde):Search("2") == 0 and not ns.QuestChain.New(horde):Build(2))
assert(ns.QuestSearch.New(alliance):Search("2")[1].id == 2 and ns.QuestSearch.New(alliance):Search("7")[1].id == 7)
assert(#ns.QuestSearch.New(human):Search("7") == 0 and ns.QuestSearch.New(human):Search("2")[1].id == 2)
assert(#ns.QuestSearch.New(forCharacter(nil, "Horde")):Search("2") == 0)
assert(ns.QuestSearch.New(forCharacter(nil, "Horde")):Search("4")[1].id == 4)
assert(ns.QuestSearch.New(forCharacter(nil, nil)):Search("2")[1].id == 2)

local hordeView = ns.QuestChain.New(horde):Build(3)
assert(#hordeView.quests == 1 and hordeView.quests[1].id == 3)
assert(#hordeView.missingIds == 0 and not hordeView.uncertainIds[3])
local hordeBrowse = ns.LocationQuestCatalog.Build(horde, locations, maps)
local hordeDungeon = hordeBrowse:Groups("dungeons", 1581)
assert(#hordeDungeon == 1 and #hordeDungeon[1].steps == 1 and hordeDungeon[1].steps[1].quest.id == 3)
local hordeRewards = ns.LocationRewardCatalog.Build(rewards):Search(hordeBrowse, "dungeons", 1581, "")
assert(#hordeRewards == 1 and hordeRewards[1].item.id == 100 and #hordeRewards[1].sources == 1)
assert(hordeRewards[1].sources[1].quest.id == 3)

local function wetlandsModel(nextQuest)
    local quests = {
        [95647] = quest("Lost in the Thicket Things", { nextQuestInChain = nextQuest }),
        [95809] = quest("Heartwoven"),
    }
    local wetlands = {
        RequireContract = function() return true end,
        Quest = {
            GetAllIds = function() return { 95647, 95809 } end,
            Exists = function(id) return quests[id] ~= nil end,
            GetAll = function(id, keys)
                local fields = {}
                for index, key in ipairs(keys) do fields[index] = quests[id][key] end
                return fields
            end,
        },
    }
    local wetlandsLookup = ns.QuestieLocationLookup.New(wetlands, maps)
    local wetlandsRepo = ns.QuestieQuestRepository.New(wetlands, wetlandsLookup)
    local wetlandsIndex = ns.QuestIndex.New(wetlandsRepo, unknownCharacter)
    return ns.QuestChain.New(wetlandsIndex), wetlandsIndex, ns.QuestieQuestLocationRepository.New(wetlands, wetlandsLookup)
end

assert(#wetlandsModel():Build(95809).quests == 1)
local wetlands, wetlandsIndex, wetlandsLocations = wetlandsModel(95809)
for _, id in ipairs({ 95647, 95809 }) do
    local chain = wetlands:Build(id)
    assert(#chain.quests == 2 and chain.quests[1].id == 95647 and chain.quests[2].id == 95809)
    assert(#chain.edges == 1 and chain.edges[1].kind == "sequence")
end
local wetlandsCatalog = ns.LocationQuestCatalog.Build(wetlandsIndex, wetlandsLocations, maps)
local missingPickup = ns.ActiveChainsQuery.Group(wetlandsCatalog, {
    [95647] = { status = "active" },
})
assert(#missingPickup == 1 and missingPickup[1].kind == "zones" and missingPickup[1].category.key == 0,
    "Keep active chains with missing pickup data visible in the unknown pickup zone section")
local context = ns.QuestLocationContext.New({
    GetClassCategories = function() return {} end,
    GetDungeon = function() return nil end,
    GetPickupZones = function() return { { key = 1 }, { key = 2 } } end,
    GetRecordedZone = function() return nil end,
}, {
    GetPlayerMapId = function() return 3 end,
    GetMap = function() return { parentMapId = 2 } end,
})
assert(context:ForQuest(2).category.key == 2, "Prefer a pickup zone that contains the player's current subzone")

local rangeQuests, rangeNeighbors, dungeonByQuest = {}, {}, {}
local function addDungeonLevels(dungeon, levels)
    local start
    for _, level in ipairs(levels) do
        local id = #rangeQuests + 1
        start = start or id
        rangeQuests[id] = { id = id, title = dungeon.name .. " quest", level = level }
        dungeonByQuest[id] = dungeon
    end
    return start
end
local plateau = { 1, 52, 52, 53, 54, 54, 55, 55, 56, 58, 59, 60, 60 }
local depthQuest = addDungeonLevels({ key = 1, name = "Depths" }, plateau)
addDungeonLevels({ key = 2, name = "Sparse" }, { 10, 30, 50 })
addDungeonLevels({ key = 3, name = "Client Range", mapId = 3 }, plateau)
addDungeonLevels({ key = 4, name = "Tight Range" }, { 50, 51, 52, 52, 52, 52, 52, 53, 60, 99 })
local prep = #rangeQuests + 1
rangeQuests[prep] = { id = prep, title = "Preparation", level = 49 }
local link = { fromId = prep, toId = depthQuest, kind = "sequence" }
rangeNeighbors[prep], rangeNeighbors[depthQuest] = { link }, { link }
local rangeCatalog = ns.LocationQuestCatalog.Build({
    Catalog = function() return rangeQuests, rangeNeighbors end,
}, {
    GetDungeon = function(_, id) return dungeonByQuest[id] end,
    GetPickupZones = function(_, id)
        local dungeon = dungeonByQuest[id]
        if not dungeon then return { { key = 100, name = "Preparation Zone" } } end
        return { { key = 100 + dungeon.key, name = dungeon.name .. " Zone", mapId = dungeon.mapId } }
    end,
    GetClassCategories = function() return {} end,
}, {
    GetLevelRange = function(_, id) if id == 3 then return 40, 61 end end,
})
local depths = rangeCatalog:Category("dungeons", 1)
assert(depths.minLevel == 52 and depths.maxLevel == 60, "Ignore a lone level-1 dungeon quest in the range")
assert(rangeCatalog:GetStep(depthQuest).quest.level == 1 and #groupWith(depths.groups, depthQuest).steps == 2,
    "The original quest level remains available")
local sparse = rangeCatalog:Category("dungeons", 2)
assert(sparse.minLevel == 10 and sparse.maxLevel == 50, "Keep the full range for a small sample")
local clientRange = rangeCatalog:Category("dungeons", 3)
assert(clientRange.minLevel == 40 and clientRange.maxLevel == 61, "Prefer the client map range")
local tight = rangeCatalog:Category("dungeons", 4)
assert(tight.minLevel == 50 and tight.maxLevel == 60, "Remove a high outlier while keeping nearby uncommon levels")
local pickup = rangeCatalog:Category("zones", 101)
assert(pickup.minLevel == 52 and pickup.maxLevel == 60, "Zone fallback ranges reject the same outliers as dungeons")
local clientZone = rangeCatalog:Category("zones", 103)
assert(clientZone.minLevel == 40 and clientZone.maxLevel == 61, "Keep the client-provided range for a zone")

local function rangeRow(kind, category, filter, status, showOutliers)
    for _, row in ipairs(rangeCatalog:Rows(kind, category, filter, status, showOutliers)) do
        if row.group.key == depthQuest then return row end
    end
end
local function allTurnedIn() return "completed" end
assert(not rangeRow("zones", 101, "completed", allTurnedIn),
    "The completed filter cannot reintroduce a hidden outlier")
assert(rangeRow("zones", 101, "completed", allTurnedIn, true).step.quest.id == depthQuest,
    "The outlier toggle restores the quest while preserving completion filtering")
local function readyOutlier(id) return id == depthQuest and "ready" or nil end
assert(rangeRow("dungeons", 1, nil, readyOutlier).step.quest.id == prep,
    "A dungeon preparation step remains visible even when the dungeon step is an outlier")
assert(rangeRow("dungeons", 1, nil, readyOutlier, true).step.quest.id == depthQuest,
    "Show outliers lets the ready dungeon step be selected")
print("browse tests passed")
