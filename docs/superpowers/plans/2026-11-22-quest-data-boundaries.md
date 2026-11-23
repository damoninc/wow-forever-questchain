# Quest data and application boundaries

> Approved Superpowers implementation plan.

**Goal** Give each feature an explicit contract for the quest data it consumes. Make it possible to trace a field from a QuestieDB or Forever API call through the rule that uses it to the view that renders it.

**Architecture** Organize business rules and use cases by feature. Define repository and gateway contracts next to their consumers. Put the concrete implementations under `Adapters/QuestieDB/` and `Adapters/Forever/`. Wire them in `Core.lua` with ordinary Lua tables and constructor arguments.

## Starting boundary

- `QuestData.lua` returns one `source` table for records, map lookups, race and class restrictions, and item-to-quest links. `Chain.lua`, `Browse.lua`, `RewardCatalog.lua`, and `Controller.lua` each consume different parts of that table.
- `ForeverQuests.lua` reads player progress, party progress, and live rewards. `Controller.lua` also calls `C_QuestLog`, `C_Timer`, `C_Map`, and unit APIs directly.
- `Chain.lua` owns graph building, quest search, and progress rules. `Browse.lua` owns location grouping and active-chain grouping. `Controller.lua` also applies business policy when it chooses a quest's browse context and assembles requirements.

## Feature structure

All paths below are relative to `ForeverQuestChain/`. The existing `UI/` template and mixin hierarchy stays the presentation boundary.

```text
Core.lua                                  # Constructs adapters and services, binds WoW events
Quests/
  QuestRepository.lua                     # Port for quest definitions and summaries
  QuestIndex.lua                          # Shared lazy quest index and graph construction
  QuestSearch.lua                         # Title and ID lookup and result ordering
  QuestChain.lua                          # Bounded chain selection and relationship policy
  QuestRequirements.lua                   # Eligibility and prerequisite rules
Locations/
  QuestLocationRepository.lua             # Port for quest location and class assignments
  MapMetadata.lua                         # Port for client map metadata and position
  LocationQuestCatalog.lua                # Group and page quests by zone, dungeon, or class
  QuestLocationContext.lua                # Choose the browse context when opening a quest
Progress/
  CharacterQuestState.lua                 # Port for character, quest log, and party facts
  QuestProgress.lua                       # Derive display status from log state and requirements
  ActiveChainsQuery.lua                   # Group active chains and pick a step to open
Rewards/
  RewardSourceRepository.lua              # Port for recorded item-to-quest links
  QuestRewardGateway.lua                  # Port for live, asynchronous reward reads
  QuestRewardLoader.lua                   # Cache, retries, invalidation, and selection guards
  LocationRewardCatalog.lua               # Search recorded rewards and assemble quest sources
Adapters/
  QuestieDB/
    QuestieQuestRepository.lua
    QuestieQuestLocationRepository.lua
    QuestieRewardSourceRepository.lua
    QuestieLocationLookup.lua             # Shared adapter implementation for map and spawn mapping
  Forever/
    ForeverCharacterQuestState.lua
    ForeverMapMetadata.lua
    ForeverQuestRewardGateway.lua
UI/
  Journal/
    JournalController.lua                 # Route, selection, and calls to feature services
    ...
```

Move `Journal.lua` under `UI/Journal/`, `Timeline.lua` next to the chain view, and `LocationArt.lua` next to the location view when updating their callers. Keep `Core.lua` as the composition root. It creates the shared `QuestIndex` once and supplies each feature its named dependencies. The journal controller receives use cases through its constructor. UI mixins receive view data and callbacks through their existing interfaces.

A lookup by quest ID goes from `QuestListMixin` to `JournalController` to `QuestSearch`. `QuestSearch` reads the shared `QuestIndex`, built from `QuestRepository` summaries. When a quest opens, `QuestChain` selects the visible steps, `QuestRepository:GetDetails` supplies the selected step's definition, and `QuestProgress` evaluates character facts. The controller sends those results to the mixins and refreshes rewards when `QuestRewardLoader` publishes a result for that selection.

### Ports and ownership

| Port | Minimum contract | Concrete implementation |
| --- | --- | --- |
| `QuestRepository` | `ListIds()`, `GetSummary(questId)`, `GetDetails(questId)`. Missing IDs return `nil`. Summary reads supply title, levels, normalized requirements, and links. Details add objectives and known pickup and turn-in points. | `QuestieQuestRepository` reads and translates the QuestieDB quest records. |
| `QuestLocationRepository` | `GetPickupZones(questId)`, `GetDungeon(questId)`, `GetClassCategories(questId)`, `GetRecordedZone(questId)`. A category has a stable key, a name, and an optional UI map ID. List methods return empty lists when no assignments are known. | `QuestieQuestLocationRepository` reads spawns, category assignments, and provider mappings. It shares map and spawn normalization with the quest repository through `QuestieLocationLookup`. |
| `MapMetadata` | `GetMap(mapId)`, `GetLevelRange(mapId)`, `GetPlayerMapId()`. Known map metadata includes a name and parent map ID. Missing fields remain absent. | `ForeverMapMetadata` owns the `C_Map` reads. |
| `CharacterQuestState` | `GetIdentity()`, `GetLevel()`, `GetProgress(questId)`, `ListLoggedQuests()`, `GetLogDetails(questId)`, `GetPartyMembersOnQuest(questId)`. These return client facts such as ready-to-turn-in and flagged-completed state. | `ForeverCharacterQuestState` reads unit and quest log APIs. `QuestProgress` decides which status wins. |
| `RewardSourceRepository` | `ListItemIds()`, `GetItem(itemId)`, `GetQuestIdsForItem(itemId)`. `ListItemIds()` returns `nil` when the provider lacks the catalog capability and an empty list when the catalog is available but empty. | `QuestieRewardSourceRepository` reads QuestieDB item records and links. |
| `QuestRewardGateway` | `Request(questId)`, `Read(questId, loadSucceeded)`. `Read` returns `nil` while data is pending or a snapshot with per-field states for XP, coin, guaranteed items, and choices. | `ForeverQuestRewardGateway` owns live quest and item API calls. `QuestRewardLoader` owns timeout, retry, invalidation, and matching replies to quest IDs. |

Use LuaLS `---@class` and `---@field` annotations to specify method signatures, record shapes, and absence semantics. Each concrete implementation and in-memory fake satisfies the same contract. Validate the QuestieDB version once before constructing its repositories, then test the adapters with a small in-memory QuestieDB fixture. Callers depend on the port shape through constructor injection. `Core.lua` passes a `schedule(delaySeconds, callback)` function for timers.

Normalize Questie-specific enums and field formats at the adapter boundary. Represent known character restriction decisions and unknown data distinctly. Keep the rule for preferring a known race decision over a faction fallback in `QuestRequirements`. Keep graph traversal, prerequisite interpretation, search sorting, category selection, and active-chain grouping in their feature modules. Repository caches own normalized upstream records. Feature indexes own derived lookups. The reward loader owns session reward state.

**Design choice** A single large `QuestRepository` would simplify wiring but keep unrelated data and consumers coupled. The proposed split keeps quest records, location assignments, and item reward links independently usable. The two game-facing state contracts are gateways to live client behavior. Add helper modules only where behavior or a cache is genuinely shared.

### Compatibility kept inside the adapters

- QuestieDB `ZoneDB` supplies area-to-map and subzone-to-parent tables. Provider override tables take precedence for matching keys. The adapter resolves pickup zones through that parent mapping and keeps the client's UI map identifiers.
- The existing Forever dungeon allowlist limits the broader provider instance table. Instance aliases and mapped child areas resolve to the same dungeon category. The existing area `10001` alias still resolves to Stratholme (`2017`).
- Class assignments prefer the provider's class and quest-sort enums. The adapter retains the existing mask and sort defaults for absent enum entries, as well as the existing localized class names. For race restrictions, the adapter decodes provider masks and the quest requirement rule gives an explicit race decision precedence over a faction decision.
- These compatibility mappings retain their current behavior. Source corrections require a separate data change backed by upstream evidence. Forever remains authoritative for live rewards, progress, and map level ranges.

## Migration steps

### 1. Establish the quest repository

- [x] Add contract cases for missing IDs, summary versus detail reads, and incoming link arrays that remain intact across repeated reads. Assert that indexing never loads objectives or spawns.
- [x] Extract `QuestieQuestRepository` from `QuestData.lua`, define the shared record contract, and wire it in `Core.lua`. Move the existing graph index and search behavior into the quest feature. Update search and chain fixtures to use an in-memory `QuestRepository`.
- [x] Verify exact ID and duplicate-title search, signed prerequisites, optional links, substitutes, cycles, and missing or omitted steps.

### 2. Give location and progress rules named owners

- [x] Add or extend fixtures for cross-zone chains, dungeon assignment versus linked steps, class categories, active-chain grouping, and race and faction precedence.
- [x] Extract the location and character ports and adapters. Move grouping, route-context selection, requirements, and progress to their named feature modules. Keep map presentation assets and timeline geometry with the views.
- [x] Audit existing QuestieDB support table and enum usage, including legacy dungeon aliases and default mappings. Record their current effect and keep the migration behavior-compatible. Handle any source corrections separately with provider evidence.

### 3. Separate recorded reward sources from live reward previews

- [x] Run quest reward and reward catalog fixtures through their respective contracts. Cover an unavailable source catalog, confirmed zero, no confirmed data, guaranteed versus pick-one items, and out-of-order quest and item replies.
- [x] Build the location reward catalog from recorded reward links. Route live requests and replies through `ForeverQuestRewardGateway` and `QuestRewardLoader`. Keep the current incremental work and timeout behavior.

### 4. Finish composition and verify the complete path

- [x] Move remaining journal coordination into `UI/Journal/JournalController.lua`. Give the controller feature operations and navigation state. Route WoW events from `Core.lua` and update TOC order, fixtures, and `AGENTS.md`.
- [x] Evaluate the boundary by running quest search, chain building, browse grouping, and reward caching with fakes in Lua 5.1. Check that direct `LibQuestieDB` and quest-related Blizzard API reads live in the owning adapters or bootstrap wiring.
- [x] Run Luacheck, Lua fixtures, `tests/runtime.py`, and the release and BigWigs packaging checks.
- [ ] Live playtest after deploying. The user runs `/reload` and `/questchain` and checks a linear chain, a join, a repeated title, a reward source round trip, and a progress update after turn-in.

## First implementation slice

Start implementation with the quest repository and one vertical path from quest ID search to chain details. That slice proves the contract against both the QuestieDB adapter and an in-memory fixture before the remaining capabilities migrate.
