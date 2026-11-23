local _, ns = ...

---@class QuestLocationContext
local QuestLocationContext = {}
QuestLocationContext.__index = QuestLocationContext
ns.QuestLocationContext = QuestLocationContext

---@param locationRepository QuestLocationRepository
---@param mapMetadata MapMetadata
function QuestLocationContext.New(locationRepository, mapMetadata)
    return setmetatable({ locationRepository = locationRepository, mapMetadata = mapMetadata }, QuestLocationContext)
end

function QuestLocationContext.FindMapCategory(mapMetadata, mapId, categoriesByMap)
    local visited = {}
    while mapId and mapId > 0 and not visited[mapId] do
        local category = categoriesByMap[mapId]
        if category then return category end
        visited[mapId] = true
        local map = mapMetadata:GetMap(mapId)
        mapId = map and map.parentMapId
    end
end

function QuestLocationContext:ForQuest(questId)
    local locations = self.locationRepository
    local classes = locations:GetClassCategories(questId)
    if #classes == 1 then return { kind = "classes", category = classes[1] } end
    local dungeon = locations:GetDungeon(questId)
    if dungeon then return { kind = "dungeons", category = dungeon } end

    local zones = locations:GetPickupZones(questId)
    if #zones == 0 then return end
    if #zones == 1 then return { kind = "zones", category = zones[1] } end

    local byMap = {}
    for _, zone in ipairs(zones) do byMap[zone.key] = zone end
    local recorded = locations:GetRecordedZone(questId)
    local category = recorded and byMap[recorded.key]
    if not category then
        category = QuestLocationContext.FindMapCategory(self.mapMetadata, self.mapMetadata:GetPlayerMapId(), byMap)
    end
    return { kind = "zones", category = category }
end
