std = "lua51"
self = false
max_line_length = false

-- Runtime APIs from Forever, Blizzard UI, and the TOC's addon dependencies.
read_globals = {
    "BACK", "COMPLETE", "QUEST_DESCRIPTION", "REWARDS",
    "REWARD_CHOICES", "REWARD_ITEMS", "REWARD_ITEMS_ONLY", "LOCALIZED_CLASS_NAMES_MALE",
    "C_Item", "C_Map", "C_QuestLog", "C_Timer", "ChatFrameUtil",
    "GameTooltip", "LibQuestieDB", "MapCanvasDataProviderMixin", "MapCanvasPinMixin",
    "Menu", "Minimap", "QuestMapFrame", "QuestTextContrast", "TomTom", "UIParent", "WorldMapFrame",
    "BreakUpLargeNumbers", "CreateFrame", "CreateFromMixins", "EJ_GetInstanceByIndex",
    "GetCursorPosition", "GetMoneyString", "GetNumQuestLogChoices", "GetNumQuestLogRewards",
    "GetNumSubgroupMembers", "GetQuestLogChoiceInfo", "GetQuestLogQuestText",
    "GetQuestLogRewardInfo", "GetQuestLogRewardMoney", "GetQuestLogRewardXP", "HaveQuestRewardData",
    "InCombatLockdown", "IsLoggedIn", "IsModifiedClick", "IsShiftKeyDown", "OpenWorldMap",
    "PanelTemplates_SetNumTabs", "PanelTemplates_SetTab", "QuestMapFrame_ShowQuestDetails",
    "UnitClass", "UnitFactionGroup", "UnitIsConnected", "UnitLevel", "UnitName", "UnitRace",
    "hooksecurefunc",
}

globals = {
    "ForeverQuestChainMapPinMixin", "ForeverQuestChainMinimapMixin", "ForeverQuestChainSettings",
    "ForeverQuestChainWindowMixin", "ForeverQuestChainQuestListMixin",
    "ForeverQuestChainTimelinePageMixin", "ForeverQuestChainQuestDetailsMixin",
    "ForeverQuestChainRewardPageMixin", "ForeverQuestChainLocationPageMixin",
    "ForeverQuestChainActiveChainsPageMixin",
    "SLASH_FOREVERQUESTCHAIN1", "SlashCmdList", "UISpecialFrames",
}
