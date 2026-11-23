local _, ns = ...

ForeverQuestChainWindowMixin = {}
local WindowMixin = ForeverQuestChainWindowMixin

local Widgets = ns.Widgets

function WindowMixin.Initialize(frame, callbacks)
    local minWidth, minHeight = 860, 460
    local bodyTop, bodyBottom, sideMargin, panelGap = 56, 53, 14, 10
    local detailWidth = 312
    local defaultWidth, defaultHeight = frame:GetSize()
    frame:SetTitle("QuestChain")
    frame:SetPortraitToAsset("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
    UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()

    local header = frame.DragHeader
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local grip = frame.ResizeGrip
    grip:SetFrameLevel(frame:GetFrameLevel() + 10)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame:HookScript("OnHide", function() frame:StopMovingOrSizing() end)

    local footer = frame.JournalTabs
    footer.minTabWidth = 92
    footer.Tabs = { footer.Search, footer.Zones, footer.Dungeons, footer.Classes, footer.ActiveChains }
    PanelTemplates_SetNumTabs(footer, #footer.Tabs)

    local catalogWidth, bodyHeight = defaultWidth - 2 * sideMargin, defaultHeight - bodyTop - bodyBottom
    local window = frame
    local function openCategory(kind, key) window:OpenCategory(kind, key) end
    local function openLocations(kind) window:OpenLocations(kind) end
    local function back() window:Back() end
    local questList, rewardPage, locationPage = frame.questList, frame.rewards, frame.locations
    local activeChainsPage, timeline, questDetails = frame.activeChains, frame.timeline, frame.questDetails
    questList:Initialize(catalogWidth, bodyHeight, callbacks)
    rewardPage:Initialize(catalogWidth, bodyHeight, callbacks.rewardPage)
    locationPage:Initialize(catalogWidth, bodyHeight, openCategory, callbacks.currentZone, callbacks.playerLevel)
    activeChainsPage:Initialize(catalogWidth, bodyHeight, callbacks.openQuest)
    timeline:Initialize(catalogWidth - detailWidth - panelGap, bodyHeight, {
        back = back, openLocations = openLocations, browseKinds = callbacks.browseKinds,
        openBrowseCategory = callbacks.openBrowseCategory, selectStep = callbacks.selectStep,
        openLinkedQuest = callbacks.openLinkedQuest, partyOnQuest = callbacks.partyOnQuest,
    })
    questDetails:Initialize(detailWidth, bodyHeight, back)

    local journal = ns.Journal.New(callbacks.playerClass)
    local tabs = { "search", "zones", "dungeons", "classes", "activeChains" }
    local tabIndex = {}
    for index, tab in ipairs(tabs) do tabIndex[tab] = index end
    local locationNav = frame.LocationNav
    local home, locationTitle = locationNav.Home, locationNav.Heading
    local questsSection, rewardsSection = locationNav.Quests, locationNav.Rewards
    Widgets.bindBreadcrumb(home)
    locationTitle:SetPoint("LEFT", home, "RIGHT", 12, 0)
    questsSection:SetScript("OnClick", function()
        window:OpenCategory(journal.route.kind, journal.route.key)
    end)
    rewardsSection:SetScript("OnClick", function()
        window:OpenCategory(journal.route.kind, journal.route.key, "rewards")
    end)

    local function showPage()
        local route = journal.route
        local page = route.page
        local open, chain = page == "search" or page == "quests", page == "chain"
        local scoped = page == "quests" or page == "rewards"
        questList:UpdateVisibility(open, scoped)
        timeline:SetShown(chain)
        questDetails:SetShown(chain)
        locationPage:SetShown(page == "locations")
        rewardPage:SetShown(page == "rewards")
        activeChainsPage:SetShown(page == "activeChains")
        locationNav:SetShown(scoped)
        if scoped then
            Widgets.setBreadcrumbText(home, route.kind == "classes" and "Search" or (route.kind == "zones" and "Zones" or "Dungeons"))
            locationTitle:SetText(callbacks.categoryName(route.kind, route.key) or "Loading...")
            questsSection:SetEnabled(page ~= "quests")
            rewardsSection:SetEnabled(page ~= "rewards")
            rewardsSection:SetShown(route.kind ~= "classes")
            questsSection:SetShown(route.kind ~= "classes")
        end
        rewardPage:ClearFocus()
        PanelTemplates_SetTab(footer, tabIndex[route.tab])
        questList:UpdateFocus(frame:IsShown())
    end

    local function navigate()
        showPage()
        callbacks.openJournalRoute(journal.route)
    end

    home:SetScript("OnClick", function()
        if journal.route.kind == "classes" then
            journal:OpenSearch()
            navigate()
        else
            window:OpenLocations(journal.route.kind)
        end
    end)

    function window:Route() return journal.route end

    function window:RefreshNavigation() showPage() end

    function window:OpenLocations(kind)
        journal:OpenLocations(kind)
        navigate()
    end

    function window:OpenCategory(kind, key, section)
        journal:OpenCategory(kind, key, section)
        navigate()
    end

    function window:IsActiveChainsOpen()
        return journal.route.page == "activeChains" and frame:IsShown()
    end

    function window:Back()
        journal:Back()
        navigate()
    end

    function window:OpenQuestPage()
        journal:OpenQuest()
        showPage()
    end

    for index, tab in ipairs(tabs) do
        footer.Tabs[index]:SetScript("OnClick", function()
            if tab == "search" then journal:OpenSearch() else journal:SelectTab(tab) end
            navigate()
        end)
    end
    showPage()

    function window:ShowJournal()
        if not frame:IsShown() then
            local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
            local scale = math.min(1, screenWidth / (defaultWidth + 20), screenHeight / (defaultHeight + 20))
            local maxWidth = math.floor(screenWidth / scale + 0.5) - 20
            local maxHeight = math.floor(screenHeight / scale + 0.5) - 20
            frame:SetScale(scale)
            frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
            local width, height = frame:GetWidth(), frame:GetHeight()
            if width > maxWidth or height > maxHeight then
                frame:SetSize(math.min(width, maxWidth), math.min(height, maxHeight))
            end
            frame:Show()
            if self:IsActiveChainsOpen() then callbacks.openActiveChains() end
            questList:UpdateFocus(true)
        end
        frame:Raise()
    end

    function window:Toggle()
        if frame:IsShown() then
            questList:UpdateFocus(false)
            rewardPage:ClearFocus()
            frame:Hide()
        else
            self:ShowJournal()
        end
    end

    frame:HookScript("OnSizeChanged", function(_, width, height)
        local newWidth = math.floor(width + 0.5) - 2 * sideMargin
        local newHeight = math.floor(height + 0.5) - bodyTop - bodyBottom
        if catalogWidth == newWidth and bodyHeight == newHeight then return end

        catalogWidth, bodyHeight = newWidth, newHeight
        questList:Resize(catalogWidth, bodyHeight)
        timeline:Resize(catalogWidth - detailWidth - panelGap, bodyHeight)
        questDetails:Resize(bodyHeight)
        rewardPage:Resize(catalogWidth, bodyHeight)
        activeChainsPage:Resize(catalogWidth, bodyHeight)
        locationPage:Resize(catalogWidth, bodyHeight)
    end)
end

ns.Window = {}

function ns.Window.New(callbacks)
    local frame = CreateFrame("Frame", "ForeverQuestChainWindow", UIParent, "ForeverQuestChainWindowTemplate")
    frame:Initialize(callbacks)
    return frame
end
