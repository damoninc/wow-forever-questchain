local _, ns = ...

local source, startupError = ns.QuestData.New(LibQuestieDB)
SLASH_FOREVERQUESTCHAIN1 = "/questchain"
if not source then
    SlashCmdList.FOREVERQUESTCHAIN = function()
        print("QuestChain: " .. startupError)
    end
    return
end

local controller = ns.Controller.New(source)
SlashCmdList.FOREVERQUESTCHAIN = function() controller:Toggle() end
ns.QuestLog.Register(function(id) controller:OpenFromQuestLog(id) end)

local events = CreateFrame("Frame")
for _, event in ipairs({
    "QUEST_DATA_LOAD_RESULT", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN",
    "QUEST_REMOVED", "PLAYER_LEVEL_UP", "GET_ITEM_INFO_RECEIVED", "GROUP_ROSTER_UPDATE",
    "UNIT_QUEST_LOG_CHANGED", "PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE",
}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, ...)
    controller:OnEvent(event, ...)
end)
