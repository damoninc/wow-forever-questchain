local function createLauncher()
    local minimap = Minimap
    if not minimap then return end
    local button = CreateFrame("Button", "ForeverQuestChainMinimapButton", minimap, "ForeverQuestChainMinimapTemplate")
    button:Initialize()
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
