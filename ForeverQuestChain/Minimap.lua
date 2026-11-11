local function createLauncher()
    local minimap = Minimap
    if not minimap then return end
    if type(ForeverQuestChainSettings) ~= "table" then ForeverQuestChainSettings = {} end
    local settings = ForeverQuestChainSettings
    local angle = tonumber(settings.minimapAngle) or math.rad(140)

    local button = CreateFrame("Button", "ForeverQuestChainMinimapButton", minimap)
    button:SetSize(31, 31)
    button:SetFrameLevel(minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    local function position()
        local x, y = math.cos(angle), math.sin(angle)
        button:SetPoint("CENTER", minimap, "CENTER",
            x * (minimap:GetWidth() / 2 + 4), y * (minimap:GetHeight() / 2 + 4))
    end
    local function hideTooltip()
        if GameTooltip and GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    end
    local function stopDrag()
        button:SetScript("OnUpdate", nil)
    end
    button:SetScript("OnClick", function() SlashCmdList.FOREVERQUESTCHAIN() end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("QuestChain")
        GameTooltip:AddLine("Click to open or close. Drag to move.", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", hideTooltip)
    button:SetScript("OnDragStart", function(self)
        hideTooltip()
        self:SetScript("OnUpdate", function()
            local centerX, centerY = minimap:GetCenter()
            if not centerX then return end
            local cursorX, cursorY = GetCursorPosition()
            local scale = minimap:GetEffectiveScale()
            angle = math.atan2(cursorY / scale - centerY, cursorX / scale - centerX)
            settings.minimapAngle = angle
            position()
        end)
    end)
    button:SetScript("OnDragStop", stopDrag)
    button:SetScript("OnHide", function()
        stopDrag()
        hideTooltip()
    end)
    minimap:HookScript("OnSizeChanged", position)
    position()
end

if IsLoggedIn() then
    createLauncher()
else
    local login = CreateFrame("Frame")
    login:RegisterEvent("PLAYER_LOGIN")
    login:SetScript("OnEvent", function(self, event)
        self:UnregisterEvent(event)
        createLauncher()
    end)
end
