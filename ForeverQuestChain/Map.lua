local _, ns = ...

local Map = {}
ns.Map = Map

local pinTemplate = "ForeverQuestChainMapPinTemplate"
local provider

ForeverQuestChainMapPinMixin = CreateFromMixins(MapCanvasPinMixin)

function ForeverQuestChainMapPinMixin:OnLoad()
    self:SetScalingLimits(1, 1, 1.2)
end

function ForeverQuestChainMapPinMixin:OnAcquired(x, y, title)
    self.title = title
    self:SetPosition(x, y)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_WAYPOINT_LOCATION")
end

function ForeverQuestChainMapPinMixin:OnMouseEnter()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.title)
    GameTooltip:Show()
end

function ForeverQuestChainMapPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

local function createProvider(map)
    local data = CreateFromMixins(MapCanvasDataProviderMixin)

    function data:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(pinTemplate)
    end

    function data:OnHide()
        self.location = nil
        self:RemoveAllData()
    end

    function data:RefreshAllData()
        self:RemoveAllData()
        local location, worldMap = self.location, self:GetMap()
        if location and worldMap:IsShown() and worldMap:GetMapID() == location.mapId then
            worldMap:AcquirePin(pinTemplate, location.x / 100, location.y / 100, location.name)
        end
    end

    map:AddDataProvider(data)
    return data
end

function Map.Show(location)
    if InCombatLockdown() then
        return false
    end
    local open = C_Map and C_Map.OpenWorldMap or OpenWorldMap
    local map = WorldMapFrame
    open(location.mapId)
    if not map:IsShown() or map:GetMapID() ~= location.mapId then
        return false
    end

    if TomTom and type(TomTom.AddWaypoint) == "function" then
        local ok, waypoint = pcall(TomTom.AddWaypoint, TomTom, location.mapId, location.x / 100, location.y / 100, {
            title = location.name, from = "QuestChain", persistent = false, silent = true,
        })
        if ok and waypoint then
            if provider then provider:OnHide() end
            return true
        end
    end

    provider = provider or createProvider(map)
    provider.location = location
    provider:RefreshAllData()
    return true
end
