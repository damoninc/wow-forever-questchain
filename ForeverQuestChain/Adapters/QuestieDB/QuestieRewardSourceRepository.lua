local _, ns = ...

local QuestieRewardSourceRepository = {}
ns.QuestieRewardSourceRepository = QuestieRewardSourceRepository

---@param lib LibQuestieDB
---@return RewardSourceRepository
function QuestieRewardSourceRepository.New(lib)
    local items = lib.Item
    local available = items and items.GetAllIds and items.name and items.questRewards
    local repository = {}

    function repository:ListItemIds()
        if available then return items.GetAllIds() end
    end

    function repository:GetItem(id)
        if not items or not items.name or (items.Exists and not items.Exists(id)) then return nil end
        local name = items.name(id)
        local level = items.requiredLevel and items.requiredLevel(id)
        return {
            id = id,
            name = name and name ~= "" and name or ("Item #" .. id),
            level = type(level) == "number" and level > 0 and level or nil,
        }
    end

    function repository:GetQuestIdsForItem(id)
        if items and items.questRewards then return items.questRewards(id) end
    end

    return repository
end
