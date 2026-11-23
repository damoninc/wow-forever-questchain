local _, ns = ...

local QuestRequirementsText = {}
ns.QuestRequirementsText = QuestRequirementsText

---@param requirements QuestRequirementDescription
---@param blocker string?
---@param satisfiedMinimumLevel number?
---@param questTitle fun(id: integer): string
---@return string?
function QuestRequirementsText.Format(requirements, blocker, satisfiedMinimumLevel, questTitle)
    local lines = {}
    if blocker then lines[#lines + 1] = blocker end
    if satisfiedMinimumLevel then lines[#lines + 1] = "Minimum level " .. satisfiedMinimumLevel end
    if requirements.uncertain then lines[#lines + 1] = "Some requirements are unclear." end

    for _, group in ipairs(requirements.groups) do
        local names = {}
        for _, option in ipairs(group.options) do
            local name = questTitle(option.questId)
            if #option.alternativeIds > 0 then
                local alternatives = { name }
                for _, id in ipairs(option.alternativeIds) do
                    alternatives[#alternatives + 1] = questTitle(id)
                end
                name = "(" .. table.concat(alternatives, " or ") .. ")"
            end
            names[#names + 1] = name
        end
        local heading = group.kind == "all" and "All required" or "Any one required"
        lines[#lines + 1] = heading .. "  /  " .. table.concat(names, ", ")
    end

    return #lines > 0 and table.concat(lines, "\n") or nil
end
