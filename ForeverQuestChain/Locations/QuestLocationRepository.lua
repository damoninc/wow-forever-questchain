---@class QuestLocationCategory
---@field key integer|string Stable category identifier.
---@field name string
---@field mapId integer? UI map ID when mapped.

---@class RecordedQuestZone
---@field key integer UI map ID.
---@field name string? Absent when the map has no metadata.
---@field mapId integer

---An empty list means no assignments are known. Category records are read-only.
---@class QuestLocationRepository
---@field GetPickupZones fun(self: QuestLocationRepository, questId: integer): QuestLocationCategory[]
---@field GetDungeon fun(self: QuestLocationRepository, questId: integer): QuestLocationCategory?
---@field GetClassCategories fun(self: QuestLocationRepository, questId: integer): QuestLocationCategory[]
---@field GetRecordedZone fun(self: QuestLocationRepository, questId: integer): RecordedQuestZone?
