local _, ns = ...

local LocationPage = {}
ns.LocationPage = LocationPage

local Widgets = ns.Widgets
local colors = Widgets.colors
local panelInset = Widgets.panelInset
local label = Widgets.label
local panel = Widgets.panel
local makeControl = Widgets.makeControl
local makeBrowseMenu = Widgets.makeBrowseMenu
local makeLocationButton = Widgets.makeLocationButton
local hideAll = Widgets.hideAll
local resetScroll = Widgets.resetScroll

function LocationPage.New(parent, top, width, height, openCategory, currentZone)
    local body, scroll, contentWidth, frame, title = panel(parent, 14, top, width, height, "DUNGEONS")
    scroll:SetPoint("TOPLEFT", 10, -78)
    local query = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    query:SetPoint("TOPLEFT", 19, -39)
    query:SetSize(360, 24)
    query:SetAutoFocus(false)
    query:SetMaxLetters(100)
    query:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local hint = label(frame, "GameFontDisableSmall", colors.muted, 23, 45, 330, "Find a location")
    local levels = makeBrowseMenu(frame, 0, 39, 155)
    levels:ClearAllPoints()
    levels:SetPoint("TOPRIGHT", -16, -39)
    local notice = label(body, "GameFontHighlightSmall", colors.muted, 4, 4, contentWidth - 8, "")
    local current = makeControl(frame, "Current Zone", 114)
    current:SetPoint("TOPRIGHT", -16, -5)
    current:SetScript("OnClick", function()
        local category = currentZone()
        if category then openCategory("zones", category.key) end
    end)
    local cards, states, artwork, mapArtwork = {}, {}, {}, {}
    local kind, entries, message, updating
    local render
    local function artFor(category)
        if kind ~= "dungeons" then return end
        if not artwork.loaded and type(EJ_GetInstanceByIndex) == "function" then
            for index = 1, 256 do
                local id, name, _, _, image = EJ_GetInstanceByIndex(index, false)
                if not id then break end
                if name and image then artwork[name:lower()] = image end
            end
            artwork.loaded = true
        end
        return artwork[category.name:lower()] or ns.LocationArt.DungeonTexture(category.key)
    end
    local function showMapArt(card, category, cardWidth, artHeight)
        if kind ~= "zones" or category.key <= 0 or not C_Map.GetMapArtLayers
            or not C_Map.GetMapArtLayerTextures then return false end
        local map = mapArtwork[category.key]
        if not map then
            local layers = C_Map.GetMapArtLayers(category.key)
            local layer = layers and layers[1]
            if not layer then return false end
            local textures = C_Map.GetMapArtLayerTextures(category.key, 1)
            if not textures or #textures == 0 then return false end
            map = { layer = layer, textures = textures }
            mapArtwork[category.key] = map
        end
        local tiles = ns.LocationArt.Tiles(map.layer, map.textures, cardWidth, artHeight)
        card.mapTiles = card.mapTiles or {}
        for index, tile in ipairs(tiles) do
            local texture = card.mapTiles[index] or card:CreateTexture(nil, "BACKGROUND")
            card.mapTiles[index] = texture
            texture:ClearAllPoints()
            texture:SetPoint("TOPLEFT", tile.x, -tile.y)
            texture:SetSize(tile.width, tile.height)
            texture:SetTexture(tile.texture)
            texture:SetTexCoord(0, tile.right, 0, tile.bottom)
            texture:Show()
        end
        return #tiles > 0
    end
    render = function(offset)
        if not kind then return end
        hideAll(cards)
        local state = states[kind]
        local filter, shown = state.query:lower(), 0
        local columns = math.max(2, math.floor((contentWidth + 12) / 190))
        local cardWidth = math.floor((contentWidth - (columns - 1) * 12) / columns)
        local cardHeight = math.floor(cardWidth * 96 / 174 + 0.5)
        for _, category in ipairs(entries) do
            local matchesLevel = not state.mine or not category.minLevel
                or (UnitLevel("player") >= category.minLevel and UnitLevel("player") <= (category.maxLevel or category.minLevel))
            if matchesLevel and category.name:lower():find(filter, 1, true) then
                shown = shown + 1
                local card = cards[shown]
                if not card then
                    card = makeLocationButton(body)
                    card:SetScript("OnClick", function(self) openCategory(kind, self.category.key) end)
                    cards[shown] = card
                end
                card.category = category
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", ((shown - 1) % columns) * (cardWidth + 12),
                    -math.floor((shown - 1) / columns) * (cardHeight + 12))
                card:SetSize(cardWidth, cardHeight)
                card.title:SetText(category.name)
                local image = artFor(category)
                if card.mapTiles then hideAll(card.mapTiles) end
                if image and card.art:SetTexture(image) then
                    -- Journal button images occupy the upper-left 175x95 of
                    -- a 256x128 texture, as in Blizzard's instance template.
                    card.art:SetTexCoord(0, 0.68359375, 0, 0.7421875)
                    card.art:Show()
                elseif showMapArt(card, category, cardWidth, cardHeight) then
                    card.art:Hide()
                else
                    card.art:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
                    card.art:SetTexCoord(0, 1, 0, 1)
                    card.art:Show()
                end
                local level = category.minLevel and (category.minLevel
                    .. ((category.maxLevel or category.minLevel) > category.minLevel and ("-" .. category.maxLevel) or ""))
                    or "Level unavailable"
                local chains, quests = 0, 0
                for _, group in ipairs(category.groups) do
                    if group.standalone then quests = quests + 1 else chains = chains + 1 end
                end
                card.counts = chains .. (chains == 1 and " chain" or " chains")
                    .. "  /  " .. quests .. (quests == 1 and " quest" or " quests")
                card.level:SetText(level)
                card:Show()
            end
        end
        notice:SetText(message or "No matching locations.")
        notice:SetShown(shown == 0)
        title:SetText((kind == "dungeons" and "DUNGEONS" or "ZONES") .. "  /  " .. shown)
        resetScroll(scroll, body, math.max(32, math.ceil(shown / columns) * (cardHeight + 12)), offset or state.offset)
    end
    scroll:HookScript("OnVerticalScroll", function(self)
        if kind then states[kind].offset = self:GetVerticalScroll() end
    end)
    query:SetScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        if updating or not kind then return end
        states[kind].query, states[kind].offset = self:GetText(), 0
        render(0)
    end)
    levels:SetupMenu(function(_, menu)
        for _, option in ipairs({ { name = "All levels", mine = false }, { name = "My level", mine = true } }) do
            local mine = option.mine
            menu:CreateRadio(option.name, function() return kind and states[kind].mine == mine end, function()
                states[kind].mine, states[kind].offset = mine, 0
                render(0)
            end)
        end
    end)
    local page = { frame = frame }

    function page:Render(nextKind, categories, text)
        kind, entries, message = nextKind, categories, text
        states[kind] = states[kind] or { query = "", mine = false, offset = 0 }
        updating = true
        query:SetText(states[kind].query)
        updating = false
        levels:GenerateMenu()
        current:SetShown(kind == "zones")
        current:SetEnabled(currentZone() ~= nil)
        render(states[kind].offset)
    end
    function page:Resize(newWidth, newHeight)
        local offset = scroll:GetVerticalScroll()
        frame:SetSize(newWidth, newHeight)
        contentWidth = newWidth - panelInset
        body:SetWidth(contentWidth)
        notice:SetWidth(contentWidth - 8)
        render(offset)
    end
    return page
end
