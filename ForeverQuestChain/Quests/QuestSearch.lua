local _, ns = ...

---@class QuestSearch
---@field private index QuestIndex
local QuestSearch = {}
QuestSearch.__index = QuestSearch
ns.QuestSearch = QuestSearch

---@param index QuestIndex
---@return QuestSearch
function QuestSearch.New(index)
    return setmetatable({ index = index }, QuestSearch)
end

---@param query string
---@return QuestSummary[]
function QuestSearch:Search(query)
    query = query:match("^%s*(.-)%s*$"):lower()
    if query == "" then
        return {}
    end
    local visible = self.index:Catalog()
    if query:match("^%d+$") then
        local quest = visible[tonumber(query)]
        return quest and { quest } or {}
    end
    local results = {}
    for _, quest in pairs(visible) do
        if quest.title:lower():find(query, 1, true) then
            results[#results + 1] = quest
        end
    end
    table.sort(results, function(left, right)
        local leftLevel, rightLevel = left.level or math.huge, right.level or math.huge
        if leftLevel ~= rightLevel then
            return leftLevel < rightLevel
        end
        local a, b = left.title:lower(), right.title:lower()
        if a == b then
            return left.id < right.id
        end
        if a == query or b == query then
            return a == query
        end
        return a < b
    end)
    return results
end
