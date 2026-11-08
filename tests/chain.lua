local ns = {}
assert(loadfile("ForeverQuestChain/QuestData.lua"))("ForeverQuestChain", ns)
assert(loadfile("ForeverQuestChain/Chain.lua"))("ForeverQuestChain", ns)

local source, reason = ns.QuestData.New(nil)
assert(source == nil and type(reason) == "string")
assert(ns.QuestData.New({ RequireContract = function() return false end }) == nil)

local function quest(id, fields)
    fields = fields or {}
    fields.id = id
    fields.title = fields.title or ("Quest " .. id)
    return fields
end

local function fixture(allOf, broken)
    local quests = {
        quest(1, { successors = { 2, 3 } }),
        quest(2, { title = "Twin", exclusiveTo = { 6 }, allOf = broken and { 4 } }),
        quest(3, { title = "Twin" }),
        quest(4, { allOf = allOf or { 2, 3 } }),
        quest(5, { anyOf = { 2, 3 } }),
        quest(6),
        quest(7, { minLevel = 15 }),
    }
    return ns.Chain.New({
        ids = function() return { 1, 2, 3, 4, 5, 6, 7 } end,
        read = function(id) return quests[id] end,
    })
end

local function player(completed, active, ready)
    return {
        level = 10,
        isCompleted = function(id) return completed[id] == true end,
        isActive = function(id) return active == id end,
        isReady = function(id) return ready == id end,
    }
end

local model = fixture()
local results = model:Search("  tWiN ")
assert(#results == 2 and results[1].id == 2 and results[2].id == 3)
assert(#model:Search("3") == 1 and model:Search("3")[1].id == 3)
assert(#model:Search("%") == 0 and #model:Search("") == 0)
assert(model:Build(999) == nil)
local view = model:Build(2)
assert(view.focusId == 2 and #view.quests == 6)
assert(view.edges[1].fromId == 1 and #view.edges == 7)
local substitute
for _, edge in ipairs(view.edges) do
    if edge.kind == "substitute" then
        substitute = edge
    end
end
assert(substitute and substitute.fromId == 6 and substitute.toId == 4)
assert(#model:Build(6).quests == 6)
assert(model:Status(4, player({ [2] = true }), view) == "blocked")
assert(model:Status(5, player({ [2] = true }), view) == "unstarted")
local threeAndSixComplete = player({ [3] = true, [6] = true })
assert(model:Status(4, threeAndSixComplete, view) == "unstarted")
local signedModel = fixture({ -2, 3 })
local signedView = signedModel:Build(2)
assert(#signedView.quests == 5)
assert(signedModel:Status(4, threeAndSixComplete, signedView) == "blocked")

local brokenModel = fixture({ 2, 999 }, true)
local brokenView = brokenModel:Build(2)
assert(brokenView.missingIds[1] == 999 and brokenView.uncertainIds[4])
assert(brokenView.uncertainIds[2])
assert(brokenModel:Status(4, player({}), brokenView) == "unstarted")
local limitedView = model:Build(2, 3)
assert(#limitedView.quests == 3 and #limitedView.omittedIds > 0)
local isolatedView = model:Build(7)
assert(#isolatedView.quests == 1 and #isolatedView.edges == 0)
assert(model:Status(7, player({}), isolatedView) == "blocked")
assert(model:Status(7, player({ [7] = true }, 7), isolatedView) == "active")
assert(model:Status(7, player({ [7] = true }, 7, 7), isolatedView) == "ready")
assert(model:Status(7, player({ [7] = true }), isolatedView) == "completed")
print("chain tests passed")
