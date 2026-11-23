local _, ns = ...

---@class ForeverQuestRewardGateway: QuestRewardGateway
local ForeverQuestRewardGateway = {}
ForeverQuestRewardGateway.__index = ForeverQuestRewardGateway
ns.ForeverQuestRewardGateway = ForeverQuestRewardGateway

---@return ForeverQuestRewardGateway
function ForeverQuestRewardGateway.New()
    return setmetatable({}, ForeverQuestRewardGateway)
end

function ForeverQuestRewardGateway:Request(id)
    C_QuestLog.RequestLoadQuestByID(id)
end

local function known(value)
    return { state = "known", value = value }
end

local function unavailable()
    return { state = "unavailable" }
end

local function amount(value, rewardsReady)
    if type(value) == "number" and (value > 0 or (value == 0 and rewardsReady)) then
        return known(value)
    end
    return unavailable()
end

local function readItems(id, count, getter, rewardsReady)
    if type(count) ~= "number" or count < 0 or (count == 0 and not rewardsReady) then
        return unavailable()
    end
    local items = {}
    for index = 1, count do
        local name, icon, quantity, _, _, itemId = getter(index, id)
        if not itemId or itemId <= 0 then
            return unavailable()
        end
        if not name or name == "" then
            name = nil
            C_Item.RequestLoadItemDataByID(itemId)
        end
        items[index] = { id = itemId, name = name, icon = icon, quantity = quantity or 1 }
    end
    return known(items)
end

function ForeverQuestRewardGateway:Read(id, loadSucceeded)
    local rewardsReady = type(HaveQuestRewardData) == "function" and HaveQuestRewardData(id) == true
    if not rewardsReady and not loadSucceeded then
        return nil
    end
    return {
        xp = amount(GetQuestLogRewardXP(id), rewardsReady),
        copper = amount(GetQuestLogRewardMoney(id), rewardsReady),
        guaranteed = readItems(id, GetNumQuestLogRewards(id), GetQuestLogRewardInfo, rewardsReady),
        choices = readItems(id, GetNumQuestLogChoices(id), GetQuestLogChoiceInfo, rewardsReady),
    }
end
