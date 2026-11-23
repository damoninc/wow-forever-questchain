---@class QuestRestrictions
---@field byRaceId table<integer, boolean?> Known race decisions, including explicit false.
---@field byFaction table<string, boolean?> Known faction decisions, including explicit false.

---@class QuestSummary
---@field id integer
---@field title string
---@field level number?
---@field minLevel number?
---@field zone string?
---@field restrictions QuestRestrictions? Absent when no character restriction is recorded.
---@field anyOf integer[]
---@field allOf integer[] Signed prerequisite references.
---@field exclusiveTo integer[] Signed exclusivity references.
---@field successors integer[]
---@field breadcrumbs integer[]
---@field breadcrumbTarget integer?
---@field parentId integer?

---@class QuestLocation
---@field name string
---@field zone string?
---@field mapId integer?
---@field x number? Map percentage paired with mapId and y when known.
---@field y number? Map percentage paired with mapId and x when known.

---@class QuestDetails: QuestSummary
---@field objectives string[]
---@field starters QuestLocation[]
---@field finishers QuestLocation[]

---Quest IDs and returned records are shared and read-only. The summary read leaves details lazy.
---@class QuestRepository
---@field ListIds fun(self: QuestRepository): integer[]
---@field GetSummary fun(self: QuestRepository, questId: integer): QuestSummary? Nil for an unknown ID.
---@field GetDetails fun(self: QuestRepository, questId: integer): QuestDetails? Nil for an unknown ID.
