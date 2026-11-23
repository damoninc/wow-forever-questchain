local ns = {}
assert(loadfile("ForeverQuestChain/UI/Journal/Locations/LocationArt.lua"))("ForeverQuestChain", ns)

local layer = { layerWidth = 1000, layerHeight = 600, tileWidth = 256, tileHeight = 256 }
local textures = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
local tiles = ns.LocationArt.Tiles(layer, textures, 200, 120)
local function near(a, b) return math.abs(a - b) < 0.00001 end
assert(#tiles == 12 and tiles[5].texture == 5 and tiles[5].x == 0 and near(tiles[5].y, 51.2),
    "Map texture IDs must remain in the client's row-major order")
local last = tiles[12]
assert(near(last.x, 153.6) and near(last.y, 102.4)
    and near(last.width, 46.4) and near(last.height, 17.6),
    "Partial map tiles must end at the card edges instead of overflowing")
assert(near(last.right, 0.90625) and near(last.bottom, 0.34375),
    "Crop padded pixels from the final row and column")
for _, tile in ipairs(tiles) do
    assert(tile.x + tile.width <= 200.00001 and tile.y + tile.height <= 120.00001)
end
assert(#ns.LocationArt.Tiles(nil, textures, 200, 120) == 0)
assert(#ns.LocationArt.Tiles(layer, { 1, 2 }, 200, 120) == 0,
    "Incomplete source maps must not render a misleading partial thumbnail")
assert(#ns.LocationArt.Tiles({ layerWidth = 0 }, textures, 200, 120) == 0,
    "Missing map dimensions must be handled without dividing by zero")
print("location art tests passed")
