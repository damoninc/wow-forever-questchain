local _, ns = ...

---@class ForeverCharacterQuestState: CharacterQuestState
local ForeverCharacterQuestState = {}
ForeverCharacterQuestState.__index = ForeverCharacterQuestState
ns.ForeverCharacterQuestState = ForeverCharacterQuestState

---@return ForeverCharacterQuestState
function ForeverCharacterQuestState.New()
    return setmetatable({}, ForeverCharacterQuestState)
end

function ForeverCharacterQuestState:GetIdentity()
    return {
        raceId = UnitRace and select(3, UnitRace("player")),
        faction = UnitFactionGroup and UnitFactionGroup("player"),
        classToken = UnitClass and select(2, UnitClass("player")),
    }
end

function ForeverCharacterQuestState:GetLevel()
    return UnitLevel("player")
end

function ForeverCharacterQuestState:GetProgress(id)
    return {
        active = not not C_QuestLog.IsOnQuest(id),
        ready = not not C_QuestLog.ReadyForTurnIn(id),
        completed = not not C_QuestLog.IsQuestFlaggedCompleted(id),
    }
end

function ForeverCharacterQuestState:ListLoggedQuests()
    local logged, zone = {}, nil
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info then
            local id = info.questID
            if info.isHeader then
                zone = info.title
            elseif id and id > 0 and not info.isHidden and not info.isTask
                and (not info.isBounty or C_QuestLog.IsComplete(id)) then
                local level = info.level and info.level > 0 and info.level or nil
                logged[id] = { level = level, zone = zone }
            end
        end
    end
    return logged
end

function ForeverCharacterQuestState:GetLogDetails(id)
    local index = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(id)
    if not index or index <= 0 then return end
    local description, objectiveText = GetQuestLogQuestText(index)
    return {
        description = description,
        objectiveText = objectiveText,
        progress = C_QuestLog.GetQuestObjectives(id),
    }
end

function ForeverCharacterQuestState:GetPartyMembersOnQuest(id)
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
