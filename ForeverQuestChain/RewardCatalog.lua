local _, ns = ...

local RewardCatalog = {}
RewardCatalog.__index = RewardCatalog
ns.RewardCatalog = RewardCatalog

function RewardCatalog.Build(source, yieldWork)
    if not source.itemIds or not source.rewardQuests or not source.rewardItem then
        return nil
    end
    local byQuest = {}
    for index, id in ipairs(source.itemIds()) do
        local questIds = source.rewardQuests(id)
        if questIds and #questIds > 0 then
            local item, seen = source.rewardItem(id), {}
            for _, questId in ipairs(questIds) do
                if not seen[questId] then
                    local items = byQuest[questId] or {}
                    byQuest[questId] = items
                    items[#items + 1] = item
                    seen[questId] = true
                end
            end
        end
        if yieldWork and index % 200 == 0 then yieldWork() end
    end
    return setmetatable({ byQuest = byQuest, locations = { zones = {}, dungeons = {} } }, RewardCatalog)
end

function RewardCatalog:Search(browse, kind, category, query)
    local locations = self.locations[kind]
    local results = locations[category]
    if not results then
        local byItem = {}
        results = {}
        for _, group in ipairs(browse:Groups(kind, category)) do
            for _, step in ipairs(group.steps) do
                if kind == "zones" or (step.dungeon and step.dungeon.key == category) then
                    for _, item in ipairs(self.byQuest[step.quest.id] or {}) do
                        local entry = byItem[item.id]
                        if not entry then
                            entry = { item = item, sources = {} }
                            byItem[item.id] = entry
                            results[#results + 1] = entry
                        end
                        entry.sources[#entry.sources + 1] = step
                    end
                end
            end
        end
        table.sort(results, function(a, b)
            local left, right = a.item.name:lower(), b.item.name:lower()
            if left == right then return a.item.id < b.item.id end
            return left < right
        end)
        locations[category] = results
    end

    query = query:match("^%s*(.-)%s*$"):lower()
    if query == "" then return results end
    local id = query:match("^%d+$") and tonumber(query)
    local matches = {}
    for _, entry in ipairs(results) do
        if (id and entry.item.id == id) or (not id and entry.item.name:lower():find(query, 1, true)) then
            matches[#matches + 1] = entry
        end
    end
    return matches
end
