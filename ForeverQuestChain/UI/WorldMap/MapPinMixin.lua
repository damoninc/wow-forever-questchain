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
