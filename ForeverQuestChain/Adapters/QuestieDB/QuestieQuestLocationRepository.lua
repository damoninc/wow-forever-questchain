local _, ns = ...

local QuestieQuestLocationRepository = {}
ns.QuestieQuestLocationRepository = QuestieQuestLocationRepository

-- The provider's instance table also includes raids, battlegrounds and older
-- expansions. These are Forever dungeon areas, with aliases read below.
local dungeonNames = {
    [209] = "Shadowfang Keep", [491] = "Razorfen Kraul", [717] = "The Stockade",
    [718] = "Wailing Caverns", [719] = "Blackfathom Deeps", [721] = "Gnomeregan",
    [722] = "Razorfen Downs", [796] = "Scarlet Monastery", [1176] = "Zul'Farrak",
    [1337] = "Uldaman", [1477] = "The Temple of Atal'Hakkar", [1581] = "The Deadmines",
    [1583] = "Blackrock Spire", [1584] = "Blackrock Depths", [2017] = "Stratholme",
    [2057] = "Scholomance", [2100] = "Maraudon", [2437] = "Ragefire Chasm",
    [2557] = "Dire Maul", [16544] = "City of Dalaran", [16611] = "Ruins of Lordaeron",
    [16732] = "Excavation Site", [16919] = "Hall of Thanes",
}
local classTokens = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local fallbackClassMasks = { 1, 2, 4, 8, 16, 64, 128, 256, 1024 }
local fallbackClassSorts = { -81, -141, -261, -162, -262, -82, -161, -61, -263 }

---@param lib LibQuestieDB
---@param locationLookup QuestieLocationLookup
---@return QuestLocationRepository
function QuestieQuestLocationRepository.New(lib, locationLookup)
    local dungeonsByArea = {}
    for areaId, name in pairs(dungeonNames) do
        local instance = locationLookup.dungeons[areaId]
        local category = {
            key = areaId,
            name = instance and instance[1] or name,
            mapId = locationLookup:GetAreaMapId(areaId),
        }
        dungeonsByArea[areaId] = category
        for _, alias in ipairs(instance and instance[2] or {}) do
            dungeonsByArea[alias] = category
        end
    end
    for alias, parent in pairs(locationLookup.parents) do
        if dungeonNames[parent] then dungeonsByArea[alias] = dungeonsByArea[parent] end
    end
    -- Preserve the existing Stratholme alias alongside the provider's aliases.
    dungeonsByArea[10001] = dungeonsByArea[2017]

    local enums = lib.Enum or {}
    local classNames, classesBySort, classMasks = {}, {}, {}
    local classKeys, sortKeys = enums.classKeys or {}, enums.sortKeys or {}
    for index, token in ipairs(classTokens) do
        local name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]
        local category = { key = token, name = name or (token:sub(1, 1) .. token:sub(2):lower()) }
        classNames[index] = category
        classMasks[index] = classKeys[token] or fallbackClassMasks[index]
        classesBySort[sortKeys[token] or fallbackClassSorts[index]] = category
    end

    local repository = {}

    function repository:GetPickupZones(id)
        local starters = locationLookup:GetStarters(id)
        local result, seen = {}, {}
        for group = 1, 2 do
            for _, entityId in ipairs(starters[group] or {}) do
                for areaId, points in pairs(locationLookup:GetSpawns(group, entityId) or {}) do
                    if #points > 0 then
                        local mapId = locationLookup:GetZoneMapId(areaId)
                        local info = mapId and locationLookup:GetMap(mapId)
                        if info and info.name and (not info.mapType or info.mapType >= 3) and not seen[mapId] then
                            seen[mapId] = true
                            result[#result + 1] = { key = mapId, name = info.name, mapId = mapId }
                        end
                    end
                end
            end
        end
        return result
    end

    function repository:GetDungeon(id)
        local assignment = locationLookup:GetQuestAssignments(id)
        return assignment and dungeonsByArea[assignment.areaId]
    end

    function repository:GetClassCategories(id)
        local assignment = locationLookup:GetQuestAssignments(id)
        if not assignment then return {} end
        local assignedClass = classesBySort[assignment.zoneOrSort]
        if assignedClass then return { assignedClass } end
        local mask = assignment.classMask
        if type(mask) ~= "number" or mask <= 0 or mask == classKeys.ALL_CLASSES then return {} end
        local result = {}
        for index, category in ipairs(classNames) do
            if math.floor(mask / classMasks[index]) % 2 == 1 then
                result[#result + 1] = category
            end
        end
        return #result < #classNames and result or {}
    end

    function repository:GetRecordedZone(id)
        local assignment = locationLookup:GetQuestAssignments(id)
        local mapId = assignment and locationLookup:GetZoneMapId(assignment.areaId)
        if not mapId then return nil end
        local info = locationLookup:GetMap(mapId)
        return { key = mapId, name = info and info.name, mapId = mapId }
    end

    return repository
end
