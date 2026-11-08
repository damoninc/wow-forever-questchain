---@meta _

-- These globals supplement the Forever client export. This file is for LuaLS.

---@type table<string, fun(message: string, editBox: EditBox)>
SlashCmdList = {}

---@type string[]
UISpecialFrames = {}

---@alias SimpleFrame Frame

---Creates a font object.
---@param name string
---@return Font font
function CreateFont(name) end

---Creates a widget and optionally applies an XML template.
---@generic T, TemplateType
---@param frameType `T`|FrameType
---@param name? string
---@param parent? Frame
---@param template? `TemplateType`|string
---@param id? number
---@return T|TemplateType|Frame frame
function CreateFrame(frameType, name, parent, template, id) end

---Returns whether the client has reward data for the quest.
---@param questID number
---@return boolean ready
function HaveQuestRewardData(questID) end

---@param questID? number
---@return number totalXP
---@return number baseXP
function GetQuestLogRewardXP(questID) end

---@param questID? number
---@return number copper
function GetQuestLogRewardMoney(questID) end

---@param questID? number
---@return number count
function GetNumQuestLogRewards(questID) end

---@param questID? number
---@param includeCurrencies? boolean
---@return number count
function GetNumQuestLogChoices(questID, includeCurrencies) end

---@param itemIndex number
---@param questID? number
---@return string? itemName
---@return number|string|nil icon
---@return number? quantity
---@return number? quality
---@return boolean? isUsable
---@return number? itemID
function GetQuestLogRewardInfo(itemIndex, questID) end

---@param choiceIndex number
---@param questID? number
---@return string? itemName
---@return number|string|nil icon
---@return number? quantity
---@return number? quality
---@return boolean? isUsable
---@return number? itemID
function GetQuestLogChoiceInfo(choiceIndex, questID) end
