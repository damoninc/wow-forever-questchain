---@meta _

---@class QuestCharacterIdentity
---@field raceId integer?
---@field faction string?
---@field classToken string?

---@class CharacterQuestProgress
---@field active boolean
---@field ready boolean
---@field completed boolean

---@class CharacterQuestLogEntry
---@field level integer?
---@field zone string? Heading of the quest's section in the native log.

---@class CharacterQuestObjective
---@field text string?
---@field type string?
---@field finished boolean?

---@class CharacterQuestLogDetails
---@field description string?
---@field objectiveText string?
---@field progress CharacterQuestObjective[]?

---@class CharacterQuestState
---@field GetIdentity fun(self: CharacterQuestState): QuestCharacterIdentity
---@field GetLevel fun(self: CharacterQuestState): integer
---@field GetProgress fun(self: CharacterQuestState, questId: integer): CharacterQuestProgress
---@field ListLoggedQuests fun(self: CharacterQuestState): table<integer, CharacterQuestLogEntry>
---@field GetLogDetails fun(self: CharacterQuestState, questId: integer): CharacterQuestLogDetails?
---@field GetPartyMembersOnQuest fun(self: CharacterQuestState, questId: integer): string[]? Names of connected party members with this quest, or nil if there are none or the client cannot check.
