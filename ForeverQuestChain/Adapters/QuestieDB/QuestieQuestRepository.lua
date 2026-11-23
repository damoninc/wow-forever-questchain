local _, ns = ...

local QuestieQuestRepository = {}
ns.QuestieQuestRepository = QuestieQuestRepository

local summaryFields = {
    "name", "questLevel", "requiredLevel", "zoneOrSort", "preQuestSingle",
    "preQuestGroup", "exclusiveTo", "childQuests", "nextQuestInChain",
    "breadcrumbs", "breadcrumbForQuestId", "parentQuest", "requiredClasses", "requiredRaces",
}
local detailFields = { "objectivesText", "finishedBy" }
local entityLabels = { "NPC #", "Object #", "Item #" }

local function positive(value)
    return type(value) == "number" and value > 0 and value or nil
end

local function copyList(values)
    local result = {}
    for index, value in ipairs(values or {}) do result[index] = value end
    return result
end

local function sharesBit(mask, factionMask)
    while mask > 0 and factionMask > 0 do
        if mask % 2 == 1 and factionMask % 2 == 1 then return true end
        mask = math.floor(mask / 2)
        factionMask = math.floor(factionMask / 2)
    end
    return false
end

---@param lib LibQuestieDB?
---@return boolean? supported
---@return string? reason
function QuestieQuestRepository.CheckContract(lib)
    if not lib or type(lib.RequireContract) ~= "function" then
        return nil, "Enable the Forever version of QuestieDB."
    end
    local supported, reason = lib.RequireContract(1)
    if not supported then
        return nil, reason or "Update QuestieDB to a compatible version."
    end
    return true
end

---@param lib LibQuestieDB
---@param locationLookup QuestieLocationLookup
---@return QuestRepository
function QuestieQuestRepository.New(lib, locationLookup)
    local quests = lib.Quest
    local summaries, details, restrictionsByMask = {}, {}, {}
    local entities = { lib.Npc, lib.Object, lib.Item }
    local enums = lib.Enum or {}
    local raceBits, factionMasks = enums.raceMaskById or {}, enums.factionRaceMasks or {}
    local repository = {}

    local function restrictions(mask)
        if not positive(mask) then return nil end
        if not restrictionsByMask[mask] then
            local byRaceId, byFaction = {}, {}
            -- Forever race masks include bits above Lua's 32-bit bit library.
            for raceId, raceBit in pairs(raceBits) do
                byRaceId[raceId] = mask % (2 * raceBit) >= raceBit
            end
            for faction, factionMask in pairs(factionMasks) do
                byFaction[faction] = sharesBit(mask, factionMask)
            end
            restrictionsByMask[mask] = { byRaceId = byRaceId, byFaction = byFaction }
        end
        return restrictionsByMask[mask]
    end

    function repository:ListIds()
        return quests.GetAllIds()
    end

    function repository:GetSummary(id)
        if summaries[id] then return summaries[id] end
        if not quests.Exists(id) then return nil end

        local fields = quests.GetAll(id, summaryFields)
        -- Nullable provider fields leave holes in the packed result.
        local name, questLevel, requiredLevel, zoneOrSort, preQuestSingle, preQuestGroup, exclusiveTo,
            childQuests, nextQuestInChain, breadcrumbs, breadcrumbForQuestId, parentQuest, requiredClasses,
            requiredRaces = unpack(fields, 1, #summaryFields)
        locationLookup:RememberQuestAssignments(id, zoneOrSort, requiredClasses)
        local successors = copyList(childQuests)
        if positive(nextQuestInChain) then successors[#successors + 1] = nextQuestInChain end
        local quest = {
            id = id,
            title = name and name ~= "" and name or ("Quest #" .. id),
            level = positive(questLevel),
            minLevel = positive(requiredLevel),
            zone = locationLookup:GetAreaName(zoneOrSort),
            anyOf = copyList(preQuestSingle),
            allOf = copyList(preQuestGroup),
            exclusiveTo = copyList(exclusiveTo),
            successors = successors,
            breadcrumbs = copyList(breadcrumbs),
            breadcrumbTarget = positive(breadcrumbForQuestId),
            parentId = positive(parentQuest),
            restrictions = restrictions(requiredRaces),
        }
        summaries[id] = quest
        return quest
    end

    local function locations(groups, areaId)
        local result = {}
        for group = 1, 3 do
            local entity = entities[group]
            for _, id in ipairs(groups[group] or {}) do
                local name = entity.name(id)
                local location = { name = name and name ~= "" and name or (entityLabels[group] .. id) }
                if group ~= 3 then
                    local spawns = locationLookup:GetSpawns(group, id)
                    if spawns and spawns[areaId] then
                        location.zone = locationLookup:GetAreaName(areaId)
                    end
                    local spawn = spawns and locationLookup:FindWaypoint(spawns, areaId)
                    if spawn then
                        location.mapId, location.x, location.y = spawn.mapId, spawn.x, spawn.y
                        location.zone = locationLookup:GetMap(spawn.mapId).name
                    end
                end
                result[#result + 1] = location
            end
        end
        return result
    end

    function repository:GetDetails(id)
        if details[id] then return details[id] end
        local base = self:GetSummary(id)
        if not base then return nil end

        local areaId = locationLookup:GetQuestAssignments(id).areaId
        local fields = quests.GetAll(id, detailFields)
        local quest = {}
        for key, value in pairs(base) do quest[key] = value end
        quest.objectives = copyList(fields[1])
        quest.starters = locations(locationLookup:GetStarters(id), areaId)
        quest.finishers = locations(fields[2] or {}, areaId)
        details[id] = quest
        return quest
    end

    return repository
end
