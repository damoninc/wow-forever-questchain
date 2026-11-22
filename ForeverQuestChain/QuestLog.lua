local _, ns = ...

local QuestLog = {}
ns.QuestLog = QuestLog

function QuestLog.Register(openQuest)
    local questLogAction = "Open in QuestChain"

    local function addQuestLogAction(owner, menu)
        local id = owner and owner.questID
        -- The gamepad quest details menu is owned by the map, rather than the quest row.
        if not id and owner == WorldMapFrame and QuestMapFrame and QuestMapFrame.DetailsFrame then
            id = QuestMapFrame.DetailsFrame.questID
        end
        if type(id) ~= "number" or id <= 0 then
            return
        end
        menu:CreateButton(questLogAction, function() openQuest(id) end)
    end

    if Menu and Menu.ModifyMenu then
        Menu.ModifyMenu("MENU_QUEST_MAP_LOG_TITLE", addQuestLogAction)
        Menu.ModifyMenu("MENU_QUEST_LOG_POPUP_DETAIL_FRAME", addQuestLogAction)
    end

    local questDetailsButton

    local function showQuestDetailsButton()
        local details = QuestMapFrame and QuestMapFrame.DetailsFrame
        local header = details and details.BackFrame
        if not header or not header.BackButton then
            return
        end
        if not questDetailsButton then
            local button = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
            button:SetPoint("LEFT", header.BackButton, "RIGHT", 6, 0)
            button:SetScript("OnClick", function()
                if details.questID then openQuest(details.questID) end
            end)
            button:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(questLogAction)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            questDetailsButton = button
        end
        local notice = header.AccountCompletedNotice
        local compact = notice and notice:IsShown()
        questDetailsButton:SetSize(compact and 36 or 126, 22)
        questDetailsButton:SetText(compact and "QC" or questLogAction)
    end

    if type(QuestMapFrame_ShowQuestDetails) == "function" then
        hooksecurefunc("QuestMapFrame_ShowQuestDetails", showQuestDetailsButton)
        if QuestMapFrame and QuestMapFrame.DetailsFrame and QuestMapFrame.DetailsFrame:IsShown() then
            showQuestDetailsButton()
        end
    end
end
