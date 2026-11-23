local ns = {}
local modules = {
    "Quests/QuestRequirements", "Quests/QuestIndex", "Quests/QuestSearch",
    "Quests/QuestChain", "Progress/QuestProgress",
}
for _, module in ipairs(modules) do
    assert(loadfile("ForeverQuestChain/" .. module .. ".lua"))("ForeverQuestChain", ns)
end

local function quest(id, fields)
    fields = fields or {}
    fields.id = id
    fields.title = fields.title or ("Quest " .. id)
    return fields
end

local function repository(quests)
    return {
        ListIds = function()
            local ids = {}
            for id in pairs(quests) do ids[#ids + 1] = id end
            table.sort(ids)
            return ids
        end,
        GetSummary = function(_, id) return quests[id] end,
        GetDetails = function() error("Indexing must use summaries") end,
    }
end

local function character(completed, active, ready, identity)
    return {
        GetIdentity = function() return identity or {} end,
        GetLevel = function() return 10 end,
        GetProgress = function(_, id)
            return { completed = completed and completed[id] == true, active = active == id, ready = ready == id }
        end,
    }
end

local function fixture(allOf, broken)
    return ns.QuestIndex.New(repository({
        quest(1, { successors = { 2, 3 } }),
        quest(2, { title = "Twin", exclusiveTo = { 6 }, allOf = broken and { 4 } }),
        quest(3, { title = "Twin" }),
        quest(4, { allOf = allOf or { 2, 3 } }),
        quest(5, { anyOf = { 2, 3 } }),
        quest(6),
        quest(7, { minLevel = 15 }),
    }), character())
end

local function status(index, id, state, view, level)
    return ns.QuestProgress.New(index, state):GetStatus(id, view, level)
end

local index = fixture()
local search = ns.QuestSearch.New(index)
local chain = ns.QuestChain.New(index)
local results = search:Search("  tWiN ")
assert(#results == 2 and results[1].id == 2 and results[2].id == 3)
assert(#search:Search("3") == 1 and search:Search("3")[1].id == 3)
assert(#search:Search("%") == 0 and #search:Search("") == 0)
assert(chain:Build(999) == nil)
local view = chain:Build(2)
assert(view.focusId == 2 and #view.quests == 6)
assert(view.edges[1].fromId == 1 and #view.edges == 7)
local substitute
for _, edge in ipairs(view.edges) do
    if edge.kind == "substitute" then
        substitute = edge
    end
end
assert(substitute and substitute.fromId == 6 and substitute.toId == 4)
assert(#chain:Build(6).quests == 6)
assert(status(index, 4, character({ [2] = true }), view) == "blocked")
assert(status(index, 5, character({ [2] = true }), view) == "unstarted")
local threeAndSixComplete = character({ [3] = true, [6] = true })
assert(status(index, 4, threeAndSixComplete, view) == "unstarted")
local requirements = ns.QuestRequirements.Describe(index:Get(4), view, index)
assert(not requirements.uncertain and #requirements.groups == 1)
local group = requirements.groups[1]
assert(group.kind == "all" and #group.options == 2)
assert(group.options[1].questId == 2 and group.options[1].alternativeIds[1] == 6)
assert(group.options[2].questId == 3 and #group.options[2].alternativeIds == 0)

local signedIndex = fixture({ -2, 3 })
local signedView = ns.QuestChain.New(signedIndex):Build(2)
assert(#signedView.quests == 5)
assert(status(signedIndex, 4, threeAndSixComplete, signedView) == "blocked")
local signedGroup = ns.QuestRequirements.Describe(signedIndex:Get(4), signedView, signedIndex).groups[1]
assert(signedGroup.options[1].questId == 2 and #signedGroup.options[1].alternativeIds == 0)

local brokenIndex = fixture({ 2, 999 }, true)
local brokenView = ns.QuestChain.New(brokenIndex):Build(2)
assert(brokenView.missingIds[1] == 999 and brokenView.uncertainIds[4])
assert(brokenView.uncertainIds[2])
assert(ns.QuestRequirements.Describe(brokenIndex:Get(4), brokenView, brokenIndex).uncertain)
assert(status(brokenIndex, 4, character(), brokenView) == "unstarted")
assert(status(brokenIndex, 4, character()) == "unstarted")

local limitedView = chain:Build(2, 3)
assert(#limitedView.quests == 3 and #limitedView.omittedIds > 0)
local isolatedView = chain:Build(7)
assert(#isolatedView.quests == 1 and #isolatedView.edges == 0)
local blocked, reason = status(index, 7, character(), isolatedView)
assert(blocked == "blocked" and reason == "Requires level 15")
assert(status(index, 7, character(), isolatedView, 15) == "unstarted")
assert(status(index, 7, character({ [7] = true }, 7), isolatedView) == "active")
assert(status(index, 7, character({ [7] = true }, 7, 7), isolatedView) == "ready")
assert(status(index, 7, character({ [7] = true }), isolatedView) == "completed")
assert(ns.QuestProgress.New(index, character(nil, 7, 7)):GetLogStatus(7) == "ready")

local cycleIndex = ns.QuestIndex.New(repository({
    quest(1, { allOf = { 2 } }),
    quest(2, { allOf = { 1 } }),
}), character())
local cycleView = ns.QuestChain.New(cycleIndex):Build(2)
assert(#cycleView.quests == 2 and #cycleView.edges == 2)
assert(cycleView.uncertainIds[1] and cycleView.uncertainIds[2])
assert(status(cycleIndex, 1, character(), cycleView) == "unstarted")

local restrictedRepository = repository({
    quest(1, { successors = { 2, 3, 4, 5, 999 } }),
    quest(2, { restrictions = { byRaceId = { [1] = false }, byFaction = { Alliance = true } } }),
    quest(3, { restrictions = { byRaceId = { [1] = true }, byFaction = { Alliance = false } } }),
    quest(4, { restrictions = { byFaction = { Alliance = false } } }),
    quest(5, { restrictions = { byRaceId = { [2] = false }, byFaction = { Horde = false } } }),
})
local restrictedIndex = ns.QuestIndex.New(restrictedRepository, character(nil, nil, nil, {
    raceId = 1, faction = "Alliance",
}))
assert(restrictedIndex:Get(2).id == 2)
local restrictedView = ns.QuestChain.New(restrictedIndex):Build(1)
assert(#restrictedView.quests == 3 and restrictedView.quests[2].id == 3 and restrictedView.quests[3].id == 5)
assert(#restrictedView.missingIds == 1 and restrictedView.missingIds[1] == 999)
assert(restrictedIndex:Get(2).id == 2 and restrictedIndex:Get(999) == nil)
local restrictedSearch = ns.QuestSearch.New(restrictedIndex)
assert(#restrictedSearch:Search("2") == 0 and #restrictedSearch:Search("5") == 1)

local manyQuests = {}
for id = 1, 81 do manyQuests[id] = quest(id) end
local incrementalIndex = ns.QuestIndex.New(repository(manyQuests), character())
local catalogWork = coroutine.create(function() return incrementalIndex:Catalog(coroutine.yield) end)
assert(coroutine.resume(catalogWork))
assert(coroutine.status(catalogWork) == "suspended")
assert(ns.QuestSearch.New(incrementalIndex):Search("81")[1].id == 81)
local indexedQuests, indexedEdges = incrementalIndex:Catalog()
local ok, resumedQuests, resumedEdges = coroutine.resume(catalogWork)
assert(ok and coroutine.status(catalogWork) == "dead")
assert(resumedQuests == indexedQuests and resumedEdges == indexedEdges)

local retryRepository = repository({ quest(1) })
local getSummary = retryRepository.GetSummary
function retryRepository:GetSummary()
    self.GetSummary = getSummary
    error("Repository temporarily unavailable")
end
local retryIndex = ns.QuestIndex.New(retryRepository, character())
assert(not pcall(retryIndex.Catalog, retryIndex))
assert(retryIndex:Catalog()[1].id == 1)
print("chain tests passed")
