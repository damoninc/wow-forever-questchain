local _, ns = ...

local ForeverQuests = {}
ns.ForeverQuests = ForeverQuests

function ForeverQuests.Player()
    return {
        level = 0,
        isActive = C_QuestLog.IsOnQuest,
        isReady = C_QuestLog.ReadyForTurnIn,
        isCompleted = C_QuestLog.IsQuestFlaggedCompleted,
    }
end

function ForeverQuests.CharacterFilter(source)
    local raceId = UnitRace and select(3, UnitRace("player"))
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return source.characterFilter(raceId, faction)
end

function ForeverQuests.ActiveLog(questLogStatus)
    local logged, zone = {}, nil
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info then
            local id = info.questID
            if info.isHeader then
                zone = info.title
            elseif id and id > 0 and not info.isHidden and not info.isTask
                and (not info.isBounty or C_QuestLog.IsComplete(id)) then
                local status = questLogStatus(id)
                if status == "active" or status == "ready" then
                    local level = info.level and info.level > 0 and info.level or nil
                    logged[id] = { level = level, zone = zone, status = status }
                end
            end
        end
    end
    return logged
end

function ForeverQuests.ReadLogDetails(id)
    local index = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
    if not index or index <= 0 then return end
    local description, objectiveText = GetQuestLogQuestText(index)
    return {
        description = description,
        objectiveText = objectiveText,
        progress = C_QuestLog.GetQuestObjectives(id),
    }
end

function ForeverQuests.PartyOnQuest(id)
    if not C_QuestLog.IsUnitOnQuest then return end
    local members
    for index = 1, GetNumSubgroupMembers() do
        local unit = "party" .. index
        if UnitIsConnected(unit) and C_QuestLog.IsUnitOnQuest(unit, id) then
            local name, realm = UnitName(unit)
            if name then
                members = members or {}
                members[#members + 1] = realm and realm ~= "" and (name .. "-" .. realm) or name
            end
        end
    end
    return members
end

local function known(value)
    return { state = "known", value = value }
end

local function unavailable()
    return { state = "unavailable" }
end

local function amount(value, rewardsReady)
    if type(value) == "number" and (value > 0 or (value == 0 and rewardsReady)) then
        return known(value)
    end
    return unavailable()
end

local function readItems(id, count, getter, rewardsReady)
    if type(count) ~= "number" or count < 0 or (count == 0 and not rewardsReady) then
        return unavailable()
    end
    local items = {}
    for index = 1, count do
        local name, icon, quantity, _, _, itemId = getter(index, id)
        if not itemId or itemId <= 0 then
            return unavailable()
        end
        if not name or name == "" then
            name = nil
            C_Item.RequestLoadItemDataByID(itemId)
        end
        items[index] = { id = itemId, name = name, icon = icon, quantity = quantity or 1 }
    end
    return known(items)
end

function ForeverQuests.ReadRewards(id, loadSucceeded)
    local rewardsReady = type(HaveQuestRewardData) == "function" and HaveQuestRewardData(id) == true
    if not rewardsReady and not loadSucceeded then
        return nil
    end
    return {
        xp = amount(GetQuestLogRewardXP(id), rewardsReady),
        copper = amount(GetQuestLogRewardMoney(id), rewardsReady),
        guaranteed = readItems(id, GetNumQuestLogRewards(id), GetQuestLogRewardInfo, rewardsReady),
        choices = readItems(id, GetNumQuestLogChoices(id), GetQuestLogChoiceInfo, rewardsReady),
    }
end
