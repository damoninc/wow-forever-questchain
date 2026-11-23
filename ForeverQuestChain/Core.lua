local _, ns = ...

local supported, startupError = ns.QuestieQuestRepository.CheckContract(LibQuestieDB)
SLASH_FOREVERQUESTCHAIN1 = "/questchain"
if not supported then
    SlashCmdList.FOREVERQUESTCHAIN = function()
        print("QuestChain: " .. startupError)
    end
    return
end

local mapMetadata = ns.ForeverMapMetadata.New()
local characterState = ns.ForeverCharacterQuestState.New()
local rewardGateway = ns.ForeverQuestRewardGateway.New()
local schedule = C_Timer.After

local locationLookup = ns.QuestieLocationLookup.New(LibQuestieDB, mapMetadata)
local questRepository = ns.QuestieQuestRepository.New(LibQuestieDB, locationLookup)
local locationRepository = ns.QuestieQuestLocationRepository.New(LibQuestieDB, locationLookup)
local rewardSources = ns.QuestieRewardSourceRepository.New(LibQuestieDB)
local questIndex = ns.QuestIndex.New(questRepository, characterState)
local questProgress = ns.QuestProgress.New(questIndex, characterState)

local controller = ns.JournalController.New({
    questRepository = questRepository,
    characterState = characterState,
    mapMetadata = mapMetadata,
    questSearch = ns.QuestSearch.New(questIndex),
    questChain = ns.QuestChain.New(questIndex),
    questProgress = questProgress,
    locationContext = ns.QuestLocationContext.New(locationRepository, mapMetadata),
    activeChains = ns.ActiveChainsQuery.New(characterState, questProgress),
    describeRequirements = function(quest, view) return ns.QuestRequirements.Describe(quest, view, questIndex) end,
    buildLocationCatalog = function(yieldWork)
        return ns.LocationQuestCatalog.Build(questIndex, locationRepository, mapMetadata, yieldWork)
    end,
    buildRewardCatalog = function(yieldWork) return ns.LocationRewardCatalog.Build(rewardSources, yieldWork) end,
    newRewardLoader = function(onUpdate) return ns.QuestRewardLoader.New(rewardGateway, schedule, onUpdate) end,
    schedule = schedule,
    createWindow = ns.Window.New,
})
SlashCmdList.FOREVERQUESTCHAIN = function() controller:Toggle() end
ns.QuestLog.Register(function(id) controller:OpenFromQuestLog(id) end)

local handlers = {
    QUEST_DATA_LOAD_RESULT = controller.OnQuestDataLoaded,
    GET_ITEM_INFO_RECEIVED = controller.OnItemDataLoaded,
    PLAYER_LEVEL_UP = controller.OnLevelUp,
    QUEST_LOG_UPDATE = controller.OnQuestLogChanged,
    QUEST_REMOVED = controller.OnQuestLogChanged,
    QUEST_ACCEPTED = controller.OnQuestProgressChanged,
    QUEST_TURNED_IN = controller.OnQuestProgressChanged,
    GROUP_ROSTER_UPDATE = controller.OnPartyChanged,
    PARTY_MEMBER_ENABLE = controller.OnPartyChanged,
    PARTY_MEMBER_DISABLE = controller.OnPartyChanged,
    UNIT_QUEST_LOG_CHANGED = function(self, unit)
        if unit == "player" then
            self:OnQuestLogChanged()
        elseif unit and unit:match("^party%d+$") then
            self:OnPartyChanged()
        end
    end,
}
local events = CreateFrame("Frame")
for event in pairs(handlers) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, ...)
    handlers[event](controller, ...)
end)
