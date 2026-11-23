local _, ns = ...

local LocationArt = {}
ns.LocationArt = LocationArt

-- Cosmetic asset names from Blizzard's journal, indexed by our existing
-- canonical dungeon area IDs. This supplies no quest or dungeon game data.
-- https://github.com/wowdev/wow-listfile/blob/master/parts/interface.csv
local dungeonImages = {
    [209] = "ShadowFangKeep", [491] = "RazorfenKraul", [717] = "TheStockade",
    [718] = "WailingCaverns", [719] = "BlackfathomDeeps", [721] = "Gnomeregan",
    [722] = "RazorfenDowns", [796] = "ScarletMonastery", [1176] = "ZulFarrak",
    [1337] = "Uldaman", [1477] = "SunkenTemple", [1581] = "Deadmines",
    [1583] = "BlackrockSpire", [1584] = "BlackrockDepths", [2017] = "Stratholme",
    [2057] = "Scholomance", [2100] = "Maraudon", [2437] = "RagefireChasm", [2557] = "DireMaul",
}

function LocationArt.DungeonTexture(areaId)
    local name = dungeonImages[areaId]
    return name and ("Interface\\EncounterJournal\\UI-EJ-DUNGEONBUTTON-" .. name)
end

function LocationArt.Tiles(layer, textures, width, height)
    if not layer or not textures or width <= 0 or height <= 0 then return {} end
    local mapWidth, mapHeight = layer.layerWidth, layer.layerHeight
    local tileWidth, tileHeight = layer.tileWidth, layer.tileHeight
    if not mapWidth or mapWidth <= 0 or not mapHeight or mapHeight <= 0
        or not tileWidth or tileWidth <= 0 or not tileHeight or tileHeight <= 0 then return {} end
    local columns, rows = math.ceil(mapWidth / tileWidth), math.ceil(mapHeight / tileHeight)
    if #textures ~= columns * rows then return {} end
    local result = {}
    for index, texture in ipairs(textures) do
        local x, y = ((index - 1) % columns) * tileWidth, math.floor((index - 1) / columns) * tileHeight
        local w, h = math.min(tileWidth, mapWidth - x), math.min(tileHeight, mapHeight - y)
        result[index] = { texture = texture, x = x * width / mapWidth, y = y * height / mapHeight,
            width = w * width / mapWidth, height = h * height / mapHeight,
            right = w / tileWidth, bottom = h / tileHeight }
    end
    return result
end
