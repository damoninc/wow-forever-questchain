local _, ns = ...

---@class ForeverMapMetadata: MapMetadata
---@field private maps table<integer, QuestMapInfo|false>
local ForeverMapMetadata = {}
ForeverMapMetadata.__index = ForeverMapMetadata
ns.ForeverMapMetadata = ForeverMapMetadata

local function positive(value)
    return type(value) == "number" and value > 0
end

---@return ForeverMapMetadata
function ForeverMapMetadata.New()
    return setmetatable({ maps = {} }, ForeverMapMetadata)
end

function ForeverMapMetadata:GetMap(id)
    if not positive(id) or not (C_Map and C_Map.GetMapInfo) then return nil end
    if self.maps[id] == nil then
        local info = C_Map.GetMapInfo(id)
        self.maps[id] = info and {
            name = info.name,
            parentMapId = info.parentMapID,
            mapType = info.mapType,
        } or false
    end
    return self.maps[id] or nil
end

function ForeverMapMetadata:GetLevelRange(id)
    if not positive(id) or not (C_Map and C_Map.GetMapLevels) then return end
    local low, high = C_Map.GetMapLevels(id)
    if positive(low) then
        return low, positive(high) and math.max(low, high) or low
    end
end

function ForeverMapMetadata:GetPlayerMapId()
    if C_Map and C_Map.GetBestMapForUnit then
        return C_Map.GetBestMapForUnit("player")
    end
end
