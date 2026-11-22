local ns = {}
local requested, ready

function HaveQuestRewardData() return ready end
function GetQuestLogRewardXP() return 120 end
function GetQuestLogRewardMoney() return 0 end
function GetNumQuestLogRewards() return 1 end
function GetNumQuestLogChoices() return 0 end
function GetQuestLogRewardInfo(index, questId)
    assert(index == 1 and questId == 42)
    return nil, 134400, 2, nil, nil, 123
end
C_Item = { RequestLoadItemDataByID = function(itemId) requested = itemId end }

assert(loadfile("ForeverQuestChain/ForeverQuests.lua"))("ForeverQuestChain", ns)
local readRewards = ns.ForeverQuests.ReadRewards

assert(readRewards(42, false) == nil)
local partial = readRewards(42, true)
assert(partial.xp.state == "known" and partial.xp.value == 120)
assert(partial.copper.state == "unavailable")
assert(partial.choices.state == "unavailable")
assert(partial.guaranteed.value[1].quantity == 2 and requested == 123)

ready = true
local confirmed = readRewards(42, false)
assert(confirmed.copper.state == "known" and confirmed.copper.value == 0)
assert(confirmed.choices.state == "known" and #confirmed.choices.value == 0)
