local _, ns = ...

local QuestData = {}
ns.QuestData = QuestData

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

local function positive(value)
    return type(value) == "number" and value > 0 and value or nil
end

local function addMapIds(target, values)
    if type(values) == "table" then
        for areaId, mapId in pairs(values) do
            target[areaId] = mapId
        end
    elseif type(values) == "string" then
        -- The provider also publishes this numeric table as Lua source.
        for areaId, mapId in values:gmatch("[\r\n]%s*%[(%d+)%]%s*=%s*(%d+)%s*,") do
            target[tonumber(areaId)] = tonumber(mapId)
        end
    end
end

function QuestData.New(lib)
    if not lib or type(lib.RequireContract) ~= "function" then
        return nil, "Enable the Forever version of QuestieDB."
    end
    local supported, reason = lib.RequireContract(1)
    if not supported then
        return nil, reason or "Update QuestieDB to a compatible version."
    end

    local quests = lib.Quest
    local mapIds, parents, summaries, details = {}, {}, {}, {}
    local zoneData = lib.Support and lib.Support.Get("ZoneDB")
    local zoneInfo = zoneData and zoneData.private or {}
    addMapIds(mapIds, zoneInfo.areaIdToUiMapId)
    addMapIds(mapIds, zoneInfo.areaIdToUiMapIdOverride)
    addMapIds(parents, zoneInfo.subZoneToParentZone)
    addMapIds(parents, zoneInfo.subZoneToParentZoneOverride)

    local maps = {}
    local function mapInfo(mapId)
        if maps[mapId] == nil then
            maps[mapId] = C_Map.GetMapInfo(mapId) or false
        end
        return maps[mapId]
    end
    local function zoneName(areaId)
        local mapId = areaId and positive(mapIds[areaId])
        local info = mapId and mapInfo(mapId)
        return info and info.name
    end

    local function summary(id)
        if summaries[id] then
            return summaries[id]
        end
        if not quests.Exists(id) then
            return nil
        end

        local fields = quests.GetAll(id, {
            "name", "questLevel", "requiredLevel", "zoneOrSort", "preQuestSingle",
            "preQuestGroup", "exclusiveTo", "childQuests", "nextQuestInChain",
            "breadcrumbs", "breadcrumbForQuestId", "parentQuest", "requiredClasses",
        })
        local successors = fields[8] or {}
        if positive(fields[9]) then
            successors[#successors + 1] = fields[9]
        end
        local title = fields[1]
        local quest = {
            id = id,
            title = title and title ~= "" and title or ("Quest #" .. id),
            level = positive(fields[2]),
            minLevel = positive(fields[3]),
            zone = zoneName(fields[4]),
            anyOf = fields[5] or {},
            allOf = fields[6] or {},
            exclusiveTo = fields[7] or {},
            successors = successors,
            breadcrumbs = fields[10] or {},
            breadcrumbTarget = positive(fields[11]),
            parentId = positive(fields[12]),
            areaId = positive(fields[4]),
            zoneOrSort = fields[4],
            classMask = fields[13],
        }
        summaries[id] = quest
        return quest
    end

    local entities = { lib.Npc, lib.Object, lib.Item }
    local entityLabels = { "NPC #", "Object #", "Item #" }
    local spawnsByEntity = { {}, {} }
    local startersByQuest = {}

    local function getSpawns(group, id)
        local cache = spawnsByEntity[group]
        if cache[id] == nil then
            cache[id] = entities[group].spawns(id) or false
        end
        return cache[id]
    end

    local function pickupZones(id)
        local starters = startersByQuest[id]
        if not starters then
            starters = quests.GetAll(id, { "startedBy" })[1] or {}
            startersByQuest[id] = starters
        end
        local result, seen = {}, {}
        for group = 1, 2 do
            for _, entityId in ipairs(starters[group] or {}) do
                for areaId, points in pairs(getSpawns(group, entityId) or {}) do
                    if #points > 0 then
                        local topArea = areaId
                        local visited = {}
                        while positive(parents[topArea]) and not visited[topArea] do
                            visited[topArea] = true
                            topArea = parents[topArea]
                        end
                        local mapId = positive(mapIds[topArea]) or positive(mapIds[areaId])
                        local info = mapId and mapInfo(mapId)
                        if info and info.name and (not info.mapType or info.mapType >= 3) and not seen[mapId] then
                            seen[mapId] = true
                            result[#result + 1] = { key = mapId, name = info.name }
                        end
                    end
                end
            end
        end
        return result
    end

    local dungeonsByArea = {}
    for areaId, name in pairs(dungeonNames) do
        local instance = (zoneInfo.dungeons or {})[areaId]
        local category = { key = areaId, name = instance and instance[1] or name }
        dungeonsByArea[areaId] = category
        for _, alias in ipairs(instance and instance[2] or {}) do
            dungeonsByArea[alias] = category
        end
    end
    for alias, parent in pairs(parents) do
        if dungeonNames[parent] then
            dungeonsByArea[alias] = dungeonsByArea[parent]
        end
    end
    dungeonsByArea[10001] = dungeonsByArea[2017]

    local enums = lib.Enum or {}
    local classNames, classesBySort, classMasks = {}, {}, {}
    for index, token in ipairs(classTokens) do
        local name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]
        local category = { key = token, name = name or (token:sub(1, 1) .. token:sub(2):lower()) }
        classNames[index] = category
        classMasks[index] = enums.classKeys and enums.classKeys[token] or fallbackClassMasks[index]
        classesBySort[enums.sortKeys and enums.sortKeys[token] or fallbackClassSorts[index]] = category
    end
    local function classes(sort, mask)
        if classesBySort[sort] then
            return { classesBySort[sort] }
        end
        if not positive(mask) or (enums.classKeys and mask == enums.classKeys.ALL_CLASSES) then
            return {}
        end
        local result = {}
        for index, category in ipairs(classNames) do
            if math.floor(mask / classMasks[index]) % 2 == 1 then
                result[#result + 1] = category
            end
        end
        return #result < #classNames and result or {}
    end

    local function mappedSpawn(spawns, areaId)
        local function point(area, coords)
            local mapId = positive(mapIds[area])
            local x, y = coords[1], coords[2]
            if mapId and mapInfo(mapId) and type(x) == "number" and type(y) == "number"
                and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
                return { mapId = mapId, x = x, y = y }
            end
        end

        local areaSpawns = spawns[areaId]
        if areaSpawns and #areaSpawns == 1 then
            local location = point(areaId, areaSpawns[1])
            if location then return location end
        end

        local unique
        for area, coords in pairs(spawns) do
            for _, coord in ipairs(coords) do
                local location = point(area, coord)
                if location then
                    if unique and (unique.mapId ~= location.mapId or unique.x ~= location.x or unique.y ~= location.y) then
                        return nil
                    end
                    unique = location
                end
            end
        end
        return unique
    end

    local function locations(groups, areaId)
        local result = {}
        for group = 1, 3 do
            local entity = entities[group]
            for _, id in ipairs(groups[group] or {}) do
                local name = entity.name(id)
                local location = { name = name and name ~= "" and name or (entityLabels[group] .. id) }
                if group ~= 3 then
                    local spawns = getSpawns(group, id)
                    local areaSpawns = spawns and areaId and spawns[areaId]
                    if areaSpawns then
                        location.zone = zoneName(areaId)
                    end
                    local spawn = spawns and mappedSpawn(spawns, areaId)
                    if spawn then
                        location.mapId, location.x, location.y = spawn.mapId, spawn.x, spawn.y
                        location.zone = mapInfo(spawn.mapId).name
                    end
                end
                result[#result + 1] = location
            end
        end
        return result
    end

    local function read(id)
        if details[id] then
            return details[id]
        end
        local base = summary(id)
        if not base then
            return nil
        end
        local fields = quests.GetAll(id, { "objectivesText", "startedBy", "finishedBy" })
        local quest = {}
        for key, value in pairs(base) do
            quest[key] = value
        end
        quest.objectives = fields[1] or {}
        quest.starters = locations(fields[2] or {}, quest.areaId)
        quest.finishers = locations(fields[3] or {}, quest.areaId)
        details[id] = quest
        return quest
    end

    return {
        ids = quests.GetAllIds, summary = summary, read = read,
        itemIds = lib.Item and lib.Item.GetAllIds,
        rewardQuests = lib.Item and lib.Item.questRewards,
        rewardItem = lib.Item and function(id)
            local name = lib.Item.name(id)
            return {
                id = id, name = name and name ~= "" and name or ("Item #" .. id),
                level = lib.Item.requiredLevel and positive(lib.Item.requiredLevel(id)),
            }
        end,
        pickupZones = pickupZones, classes = classes,
        dungeon = function(areaId) return dungeonsByArea[areaId] end,
        categoryLevels = function(kind, key)
            local mapId = kind == "zones" and positive(key) or (kind == "dungeons" and positive(mapIds[key]))
            if mapId and C_Map.GetMapLevels then
                local low, high = C_Map.GetMapLevels(mapId)
                if positive(low) then
                    return low, positive(high) and math.max(low, high) or low
                end
            end
        end,
        zoneParent = function(mapId)
            local info = mapInfo(mapId)
            return info and info.parentMapID
        end,
    }
end
