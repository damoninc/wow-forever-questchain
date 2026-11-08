# QuestChain Browse Implementation Plan

> Use superpowers:executing-plans for the approved inline build. Steps use checkboxes.

**Goal** Find quests without a name by browsing grouped chains under Zones, Dungeons, and Classes.

**Architecture** Extend the existing data adapter with pickup and category reads. Build a lazy browse index over the existing quest graph and connect its grouped results to the current timeline and reward flow.

**Tech stack** Lua 5.1, native Forever frames, and QuestieDB.

**Spec** [QuestChain category browsing](../specs/2026-11-08-questchain-browse-design.md)

## Global constraints

- Browse zones by known pickup, preserving cross-zone chains and multiple starters.
- Group verified dungeon assignments and aliases. Use recognized class sorts first and restricted masks otherwise.
- Use stable quest IDs for identity. Use current-character status and keep the existing bounded timeline.
- Keep category building off the login path and all results reachable. Read rewards only for the selected quest.

## Review focus

- A cross-zone chain retains one identity and shows its pickup steps in each zone.
- Shared breadcrumbs and substitutes preserve separate structural chains.
- A breadcrumb row opens its destination chain with the breadcrumb selected.
- Completed filtering and paging keep the rest of the list accessible.
- Unknown pickup and universal class masks have distinct treatment.

## Tasks

- [x] **Quest data.** Extend `QuestData.lua` summaries with `zoneOrSort` and `classMask`. Provide `pickupZones(id)`, `dungeon(areaId)`, and `classes(sort, mask)`. Each category is `{ key, name }`. Cache NPC and object locations and normalize subzone and dungeon IDs using QuestieDB support. Use fixtures for cross-zone starts, missing pickup, dungeon aliases, class sorts, and restricted masks.
- [x] **Group index.** Add `Browse.lua` with `Build(model, source, yieldWork)`, `Categories(kind)`, and `Groups(kind, key)`. Derive stable connected components from structural links, then attach unambiguous optional-only steps. Each result step carries its quest and optional destination ID. Expose a graph read through `Chain.lua` and support an optional destination when opening a breadcrumb. Run the fixtures for shared optional quests, duplicate titles, and cross-zone membership.
- [x] **Browse pane.** Add a Search and Browse switch in `Window.lua`. Show category buttons, Current Zone and My Class shortcuts, chain headers, selectable steps, Hide completed, and paging. Keep navigation and scroll state in session. In `Core.lua`, build the index in batches on first Browse and reuse the existing open-quest flow. Test stepping into a chain, switching modes, browsing beyond 80 results, and refreshing progress.
- [x] **Verify and deploy.** Run all Lua fixtures, load the TOC-listed modules in the simulated client, and check the installed addon path before copying changed runtime files. Document the Browse controls.
- [ ] **Live acceptance.** Test representative zone, dungeon, and class quests in Forever and check cold-start responsiveness.

The dungeon picker starts with verified classic areas and four Forever-original dungeon area mappings available in the provider's dungeon table. Categories appear when QuestieDB has a matching assignment. Additional Forever dungeon mappings can be added when verified.
