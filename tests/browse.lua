local ns = {}
for _, file in ipairs({ "QuestData", "Chain", "Browse" }) do
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
    [3] = quest("The Finale", { startedBy = { { 11 } }, zoneOrSort = 1581 }),
    [4] = quest("The Plot", { startedBy = { { 11 } }, zoneOrSort = 2717 }),
    [5] = quest("An Invitation", { startedBy = { { 12 } }, breadcrumbForQuestId = 2 }),
    [6] = quest("A Shared Lead", { startedBy = { { 12 } } }),
    [7] = quest("Class Lesson", { startedBy = { [3] = { 99 } }, zoneOrSort = -161 }),
    [8] = quest("Class Training", { requiredClasses = 129 }),
    [9] = quest("General Training", { requiredClasses = 131 }),
}
records[1].breadcrumbs, records[4].breadcrumbs = { 6 }, { 6 }
for id = 10, 94 do
    records[id] = quest("Local errand " .. id, { startedBy = { { 11 } } })
end

C_Map = {
    GetMapInfo = function(id)
        return ({ [1] = { name = "Stormwind" }, [2] = { name = "Westfall" },
            [3] = { name = "Moonbrook", parentMapID = 2 } })[id]
    end,
}

local spawnCalls = 0
local source = assert(ns.QuestData.New({
    RequireContract = function() return true end,
    Enum = { sortKeys = { MAGE = -161 }, classKeys = { WARRIOR = 1, PALADIN = 2, MAGE = 128, ALL_CLASSES = 131 } },
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
assert(#westfallPlot.steps == 2 and westfallPlot.steps[1].quest.id == 5)
assert(westfallPlot.steps[1].destination == 2 and westfallPlot.steps[2].quest.id == 2)
assert(groupWith(westfall, 6).steps[1].quest.id == 6)
assert(groupWith(stormwind, 4).title == stormwindPlot.title)
assert(browse:MatchZone(3).key == 2)
assert(spawnCalls == 3)

local dungeonGroups = browse:Groups("dungeons", 1581)
assert(#dungeonGroups == 1 and #dungeonGroups[1].steps == 2)
assert(#browse:Groups("dungeons", 2717) == 0)
assert(#browse:Groups("classes", "MAGE") == 2)
assert(#browse:Groups("classes", "WARRIOR") == 1)
assert(#browse:Groups("classes", "PALADIN") == 0)
assert(#browse:Groups("zones", 0) == 3)

local rows = browse:Rows("zones", 1, {}, function() return false end)
local last, page, count = ns.Browse.Page(rows, 999)
assert(count >= 3 and page == count and #last > 0)
local first = browse:Rows("zones", 1, { [1] = true }, function(id) return id == 4 end)
local hiddenGroup, collapsed
for _, row in ipairs(first) do
    hiddenGroup = hiddenGroup or row.group.key == 4
    if row.group.key == 1 then collapsed = not row.step end
end
assert(not hiddenGroup and collapsed)

local view = model:Build(5, nil, westfallPlot.steps[1].destination)
assert(view.focusId == 5 and #view.quests == 5)
print("browse tests passed")
