---@meta _

---@alias QuestRewardState "loading"|"unavailable"|"known"

---@class QuestRewardAmount
---@field state QuestRewardState
---@field value number? Present for a known amount, including confirmed zero.

---@class QuestRewardItem
---@field id integer
---@field name string? May be absent while the client loads item data.
---@field icon number|string|nil
---@field quantity integer

---@class QuestRewardItems
---@field state QuestRewardState
---@field value QuestRewardItem[]? Present for known items, including a confirmed empty list.

---@class QuestRewardView
---@field xp QuestRewardAmount
---@field copper QuestRewardAmount
---@field guaranteed QuestRewardItems
---@field choices QuestRewardItems

---@class QuestRewardGateway
---@field Request fun(self: QuestRewardGateway, questId: integer)
---@field Read fun(self: QuestRewardGateway, questId: integer, loadSucceeded: boolean): QuestRewardView? Returns nil while pending. A returned view may contain unavailable fields.
