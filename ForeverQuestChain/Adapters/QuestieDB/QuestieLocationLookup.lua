local _, ns = ...

local QuestieLocationLookup = {}
ns.QuestieLocationLookup = QuestieLocationLookup

local function positive(value)
    return type(value) == "number" and value > 0 and value or nil
end

local function addMapIds(target, values)
    if type(values) == "table" then
        for areaId, mapId in pairs(values) do
            target[areaId] = mapId
        end
    elseif type(values) == "string" then
        -- QuestieDB also publishes these numeric tables as Lua source.
        for areaId, mapId in values:gmatch("[\r\n]%s*%[(%d+)%]%s*=%s*(%d+)%s*,") do
            target[tonumber(areaId)] = tonumber(mapId)
        end
    end
end

---@param lib LibQuestieDB
---@param mapMetadata MapMetadata
---@return QuestieLocationLookup
function QuestieLocationLookup.New(lib, mapMetadata)
    local quests = lib.Quest
    local zoneData = lib.Support and lib.Support.Get("ZoneDB")
    local zoneInfo = zoneData and zoneData.private or {}
    local mapIds, parents = {}, {}
    addMapIds(mapIds, zoneInfo.areaIdToUiMapId)
    addMapIds(mapIds, zoneInfo.areaIdToUiMapIdOverride)
    addMapIds(parents, zoneInfo.subZoneToParentZone)
    addMapIds(parents, zoneInfo.subZoneToParentZoneOverride)

    local assignments, starters = {}, {}
    local spawnEntities, spawnsByEntity = { lib.Npc, lib.Object }, { {}, {} }
    local assignmentFields = { "zoneOrSort", "requiredClasses" }

    ---@class QuestieLocationLookup
    local lookup = { dungeons = zoneInfo.dungeons or {}, parents = parents }

    function lookup:GetMap(mapId)
        return mapMetadata:GetMap(mapId)
    end

    function lookup:GetAreaMapId(areaId)
        return positive(mapIds[areaId])
    end

    function lookup:GetAreaName(areaId)
        local mapId = self:GetAreaMapId(areaId)
        local info = mapId and self:GetMap(mapId)
        return info and info.name
    end

    function lookup:GetZoneMapId(areaId)
        local topArea, visited = areaId, {}
        while positive(parents[topArea]) and not visited[topArea] do
            visited[topArea] = true
            topArea = parents[topArea]
        end
        return self:GetAreaMapId(topArea) or self:GetAreaMapId(areaId)
    end

    function lookup:RememberQuestAssignments(id, zoneOrSort, classMask)
        local assignment = { zoneOrSort = zoneOrSort, areaId = positive(zoneOrSort), classMask = classMask }
        assignments[id] = assignment
        return assignment
    end

    function lookup:GetQuestAssignments(id)
        local assignment = assignments[id]
        if assignment then return assignment end
        if not quests.Exists(id) then return nil end
        local fields = quests.GetAll(id, assignmentFields)
        return self:RememberQuestAssignments(id, fields[1], fields[2])
    end

    function lookup:GetStarters(id)
        if not starters[id] then
            if not quests.Exists(id) then return {} end
            starters[id] = quests.GetAll(id, { "startedBy" })[1] or {}
        end
        return starters[id]
    end

    function lookup:GetSpawns(group, id)
        local cache = spawnsByEntity[group]
        if cache[id] == nil then
            cache[id] = spawnEntities[group].spawns(id) or false
        end
        return cache[id] or nil
    end

    local function point(areaId, coords)
        local mapId = lookup:GetAreaMapId(areaId)
        local x, y = coords[1], coords[2]
        if mapId and lookup:GetMap(mapId) and type(x) == "number" and type(y) == "number"
            and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
            return { mapId = mapId, x = x, y = y }
        end
    end

    function lookup:FindWaypoint(spawns, areaId)
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

    return lookup
end
