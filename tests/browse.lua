local ns = {}
for _, file in ipairs({ "QuestData", "Chain", "Browse", "RewardCatalog" }) do
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
    [5] = quest("An Invitation", { startedBy = { { 12 } }, breadcrumbForQuestId = 2 }),
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
local source = assert(ns.QuestData.New({
    RequireContract = function() return true end,
    Enum = {
        sortKeys = { MAGE = -161 },
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
    },
    Npc = { spawns = function(id)
        spawnCalls = spawnCalls + 1
        return ({ [11] = { [1519] = {{1, 1}} }, [12] = { [40] = {{1, 1}} },
            [13] = { [108] = {{1, 1}}, [1519] = {{1, 1}} } })[id]
    end },
    Support = { Get = function()
        return { private = {
            areaIdToUiMapId = { [1519] = 1, [40] = 2, [108] = 3 },
            subZoneToParentZone = { [108] = 40 },
            dungeons = { [1581] = { "The Deadmines", { 10029 } }, [2717] = { "Molten Core" } },
        } }
    end },
}))

local model = ns.Chain.New(source)
local work = coroutine.create(function() return ns.Browse.Build(model, source, coroutine.yield) end)
assert(coroutine.resume(work))
assert(coroutine.status(work) == "suspended" and model.quests == nil and spawnCalls == 0)
assert(model:Search("A Lead")[1].id == 2)
local search = model:Search("Local errand")
assert(search[1].id == 11 and search[2].id == 94 and search[3].id == 10 and search[6].id == 12)
local browse
while coroutine.status(work) ~= "dead" do
    local ok, result = coroutine.resume(work)
    assert(ok, result)
    browse = result
end
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
assert(#browse:Groups("classes", "MAGE") == 2)
assert(#browse:Groups("classes", "WARRIOR") == 1)
assert(#browse:Groups("classes", "PALADIN") == 0)
assert(#browse:Groups("zones", 0) == 3)

local function questStatus(id)
    return ({ [1] = "completed", [2] = "active", [3] = "ready" })[id]
end
local rows = browse:Rows("zones", 1, nil, questStatus)
local last, page, count = ns.Browse.Page(rows, 999)
assert(count >= 3 and page == count and #last > 0)
assert(#rows == #stormwind)
assert(rows[1].group.key == 1 and rows[1].step.quest.id == 3 and rows[1].status == "active" and rows[1].completed == 1)
assert(rows[2].group.key == 20 and rows[3].group.key == 11 and rows[4].group.key == 94)
for index = 3, #rows do assert(rows[index].group.standalone) end
local completed = browse:Rows("zones", 1, "completed", questStatus)
assert(#completed == 1 and completed[1].group.key == 1 and completed[1].step.quest.id == 1)
assert(completed[1].status == "active")
local allComplete = browse:Rows("zones", 2, nil, function() return "completed" end)
assert(#allComplete == 2 and allComplete[1].status == "completed")
assert(browse:Rows("zones", 2, "incomplete", function() return "completed" end)[1] == nil)

local view = model:Build(5, nil, westfallPlot.steps[1].destination)
assert(view.focusId == 5 and #view.quests == 5)

local function forCharacter(raceId, faction)
    return ns.Chain.New(source, function() return source.characterFilter(raceId, faction) end)
end
local alliance = forCharacter(95, "Alliance")
local horde = forCharacter(96, "Horde")
local human = forCharacter(1, "Alliance")
local plots = alliance:Search("The Plot")
assert(#plots == 1 and plots[1].id == 1)
assert(#horde:Search("The Plot") == 2)
assert(#horde:Search("2") == 0 and not horde:Build(2))
assert(alliance:Search("2")[1].id == 2 and alliance:Search("7")[1].id == 7)
assert(#human:Search("7") == 0 and human:Search("2")[1].id == 2)
assert(#forCharacter(nil, "Horde"):Search("2") == 0)
assert(forCharacter(nil, "Horde"):Search("4")[1].id == 4)
assert(forCharacter(nil, nil):Search("2")[1].id == 2)

local hordeView = horde:Build(3)
assert(#hordeView.quests == 1 and hordeView.quests[1].id == 3)
assert(#hordeView.missingIds == 0 and not hordeView.uncertainIds[3])
local hordeBrowse = ns.Browse.Build(horde, source)
local hordeDungeon = hordeBrowse:Groups("dungeons", 1581)
assert(#hordeDungeon == 1 and #hordeDungeon[1].steps == 1 and hordeDungeon[1].steps[1].quest.id == 3)
local hordeRewards = ns.RewardCatalog.Build(source):Search(hordeBrowse, "dungeons", 1581, "")
assert(#hordeRewards == 1 and hordeRewards[1].item.id == 100 and #hordeRewards[1].sources == 1)
assert(hordeRewards[1].sources[1].quest.id == 3)

local function wetlandsModel(nextQuest)
    local quests = {
        [95647] = quest("Lost in the Thicket Things", { nextQuestInChain = nextQuest }),
        [95809] = quest("Heartwoven"),
    }
    local wetlands = assert(ns.QuestData.New({
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
    }))
    return ns.Chain.New(wetlands)
end

assert(#wetlandsModel():Build(95809).quests == 1)
local wetlands = wetlandsModel(95809)
for _, id in ipairs({ 95647, 95809 }) do
    local chain = wetlands:Build(id)
    assert(#chain.quests == 2 and chain.quests[1].id == 95647 and chain.quests[2].id == 95809)
    assert(#chain.edges == 1 and chain.edges[1].kind == "sequence")
end
print("browse tests passed")
