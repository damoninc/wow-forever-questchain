---@class RecordedRewardItem
---@field id integer
---@field name string
---@field level number? Recorded minimum level when known.

---Recorded item links and item IDs are read-only.
---@class RewardSourceRepository
---@field ListItemIds fun(self: RewardSourceRepository): integer[]? Nil when catalog support is unavailable.
---@field GetItem fun(self: RewardSourceRepository, itemId: integer): RecordedRewardItem?
---@field GetQuestIdsForItem fun(self: RewardSourceRepository, itemId: integer): integer[]? Nil when no links are known.
