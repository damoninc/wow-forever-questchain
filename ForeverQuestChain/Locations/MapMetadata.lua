---@meta _

---@class QuestMapInfo
---@field name string?
---@field parentMapId integer?
---@field mapType integer?

---@class MapMetadata
---@field GetMap fun(self: MapMetadata, mapId: integer?): QuestMapInfo? Missing maps return nil.
---@field GetLevelRange fun(self: MapMetadata, mapId: integer?): integer?, integer? Both levels are absent when the minimum is unknown.
---@field GetPlayerMapId fun(self: MapMetadata): integer?
