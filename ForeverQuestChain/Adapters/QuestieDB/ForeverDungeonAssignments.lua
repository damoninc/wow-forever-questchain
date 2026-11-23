local _, ns = ...

-- Temporary location-only fallback for QuestieDB 1.1.4. The keys are
-- instance AreaTable IDs. Quest IDs are limited to dungeon-tagged entries.
-- Zone IDs: https://www.wowhead.com/forever/zones
ns.ForeverDungeonAssignments = {
    -- https://db.icy-veins.com/wow-forever/quests/zones/the-drowned-city/
    [16550] = {
        name = "The Drowned City",
        quests = { 95775, 95776, 95787, 95788, 95789, 95791, 96774, 97130 },
    },
    -- https://db.icy-veins.com/wow-forever/quests/zones/blackmaw-hold/
    [16554] = {
        name = "Blackmaw Hold",
        quests = { 92065, 92066, 92067, 92069, 92070, 92343, 92344, 96246, 97173, 97198, 97327 },
    },
    -- https://db.icy-veins.com/wow-forever/quests/zones/alcaz-prison/
    [16620] = {
        name = "Alcaz Prison",
        quests = { 95262, 95263, 95309, 95454, 95483, 96332, 96334, 96335, 96337, 96369, 96381, 96772 },
    },
    -- https://db.icy-veins.com/wow-forever/quests/zones/the-shaper-s-terrace/
    [16667] = {
        name = "The Shaper's Terrace",
        quests = { 95790, 95924, 95925, 95926, 95928, 97049 },
    },
    -- https://db.icy-veins.com/wow-forever/quests/zones/krol-dok-stronghold/
    [16842] = {
        name = "Krol'dok Stronghold",
        quests = { 94968, 94969, 94972, 94975, 94982, 94983, 94984, 95056, 96771 },
    },
}
