local ns = {}
assert(loadfile("ForeverQuestChain/Timeline.lua"))("ForeverQuestChain", ns)

local function edge(fromId, toId, kind)
    return { fromId = fromId, toId = toId, kind = kind or "sequence" }
end

local function layout(ids, edges)
    local quests = {}
    for _, id in ipairs(ids) do
        quests[#quests + 1] = { id = id }
    end
    return ns.Timeline.Layout({ quests = quests, edges = edges }, 399)
end

local function center(card)
    return card.x + card.width / 2
end

local linear = layout({ 1, 2, 3 }, { edge(1, 2), edge(2, 3) })
local cards = linear.cards
assert(center(cards[1]) == center(cards[2]) and center(cards[2]) == center(cards[3]))
assert(cards[1].y < cards[2].y and cards[2].y < cards[3].y)
assert(#linear.segments == 2)

-- The input's topological order completes one route before the other.
local fork = layout({ 1, 2, 4, 3, 5, 6 }, {
    edge(1, 2), edge(1, 3), edge(2, 4), edge(3, 5), edge(4, 6, "all"), edge(5, 6, "all"),
})
cards = fork.cards
assert(cards[2].y == cards[3].y and cards[4].y == cards[5].y)
assert(cards[2].x + cards[2].width < cards[3].x)
assert(center(cards[2]) == center(cards[4]) and center(cards[3]) == center(cards[5]))
assert(center(cards[1]) == center(cards[6]) and cards[6].y > cards[5].y)

-- An alternative can appear after its target in the chain's input order.
local optional = layout({ 1, 2, 3 }, { edge(1, 2, "all"), edge(3, 2, "substitute") })
assert(optional.cards[1].y == optional.cards[3].y)
assert(optional.cards[3].y < optional.cards[2].y)
assert(optional.notes[3] == "Prerequisite alternative")
local hasOptionalLine = false
for _, segment in ipairs(optional.segments) do
    hasOptionalLine = hasOptionalLine or segment.optional
end
assert(hasOptionalLine)

local broken = layout({ 1, 2 }, { edge(1, 2), edge(2, 1), edge(2, 2, "breadcrumb") })
assert(broken.hasUnorderedLinks and #broken.segments == 1)

-- Long connections should run around cards on intervening tiers.
local long = layout({ 1, 2, 3 }, { edge(1, 2), edge(2, 3), edge(1, 3, "breadcrumb") })
local usedGutter = false
for _, segment in ipairs(long.segments) do
    if segment.optional and segment.x1 == segment.x2 and segment.y1 < long.cards[2].y
        and segment.y2 > long.cards[2].y + long.cards[2].height then
        assert(segment.x1 < long.cards[2].x or segment.x1 > long.cards[2].x + long.cards[2].width)
        usedGutter = true
    end
end
assert(usedGutter)

local wide = layout({ 1, 2, 3, 4, 5, 6 }, {
    edge(1, 2), edge(1, 3), edge(1, 4), edge(1, 5), edge(1, 6),
})
assert(wide.width > 399)
for id = 2, 6 do
    assert(wide.cards[id].y == wide.cards[2].y and wide.cards[id].width >= 112)
end
assert(wide.cards[6].x + wide.cards[6].width < wide.width)

print("timeline layout tests passed")
