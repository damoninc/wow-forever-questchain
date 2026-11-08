local ns = {}
assert(loadfile("ForeverQuestChain/Rewards.lua"))("ForeverQuestChain", ns)

local requests, timers, delivered = {}, {}, {}
local readValues = {
    [166] = {
        xp = { state = "known", value = 6200 },
        copper = { state = "unavailable" },
        guaranteed = { state = "known", value = {} },
        choices = { state = "known", value = { { id = 6087, quantity = 1 } } },
    },
    [5724] = {
        xp = { state = "known", value = 2200 },
        copper = { state = "known", value = 0 },
        guaranteed = { state = "known", value = {} },
        choices = { state = "known", value = {} },
    },
}
local ready = {}
local rewards = ns.Rewards.New({
    request = function(id) requests[#requests + 1] = id end,
    after = function(seconds, callback)
        assert(seconds == 3)
        timers[#timers + 1] = callback
    end,
    read = function(id, loaded)
        if loaded or ready[id] then
            return readValues[id]
        end
    end,
}, function(id, view)
    assert(view.xp.state ~= "loading")
    delivered[#delivered + 1] = id
end)

local initial = rewards:Select(166)
assert(initial.xp.state == "loading")
rewards:Select(166)
rewards:Select(5724)
assert(requests[1] == 166 and requests[2] == 5724 and #requests == 2)
rewards:OnQuestDataLoaded(166, true)
assert(rewards:Get(166).xp.value == 6200)
assert(rewards:Get(166).copper.state == "unavailable")
rewards:OnQuestDataLoaded(5724, true)
assert(rewards:Get(5724).copper.state == "known")
assert(rewards:Get(5724).copper.value == 0)
assert(#delivered == 1 and delivered[1] == 5724)
timers[2]()
assert(rewards:Get(5724).xp.value == 2200)

rewards:Select(999)
rewards:OnQuestDataLoaded(999, false)
assert(rewards:Get(999).xp.state == "unavailable")
rewards:Select(999)
timers[#timers]()
assert(rewards:Get(999).xp.state == "unavailable")
rewards:Select(999)
timers[#timers - 1]()
assert(rewards:Get(999).xp.state == "loading")

rewards:Select(5724)
ready[5724] = true
readValues[5724].xp = { state = "known", value = 2400 }
rewards:Invalidate()
assert(rewards:Get(5724).xp.value == 2400)
assert(delivered[#delivered] == 5724)
assert(rewards:Select(5724).xp.value == 2400)
print("reward tests passed")
