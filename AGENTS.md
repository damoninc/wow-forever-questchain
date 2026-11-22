# QuestChain development guide

## Product purpose

QuestChain is an in-game quest-chain reference for **World of Warcraft: Forever**. Its job is to let players answer three questions without leaving the game, including before they accept a quest.

- Where does this quest fit in the chain, and what have I already done?
- What comes next, and which prerequisites or alternate routes matter?
- What are the objectives, pickup and turn-in locations, and rewards for this step?

Keep the path from search to an answer short. Prioritize a readable timeline, accurate character progress, and reliable previews of XP, coin, and item rewards.

## Player experience

- `/questchain` opens the addon. Search by quest name or exact ID, including quests outside the current log. Use quest IDs internally and show enough context to distinguish duplicate titles.
- Browse groups quests by chain under pickup zone, verified dungeon assignment, or class. A cross-zone chain can appear in each zone with the steps picked up there. Dungeon results include linked chain steps with their dungeon context. Zone and dungeon pickers sort by level, as do catalog results. Selecting a Browse result opens the timeline at that step.
- The journal uses persistent Search, Zones, Dungeons, and Active Chains tabs. Zones and Dungeons open card grids sorted by level, then location pages with Quests and Rewards sections. Class browsing remains accessible from Search. Quest timelines are drilldown pages within their originating tab; Back returns to the originating list or reward sources. Keep filters and page controls outside scrolling results, and preserve each tab's location, filters, page, and position. The timeline gets most of the chain page with quest details on the right.
- The approved timeline runs top to bottom. Center linear steps, place sibling steps side by side, and draw connectors where paths split or rejoin. Label all-required and any-one-required joins. Keep cards readable on wide forks and support horizontal panning with Shift + mouse wheel.
- Selecting a search result brings its step into view. Clicking a step within the chain updates the detail panel and preserves the scroll position. Mark the selected step separately from progress, and use text as well as color for quest status.
- Show objectives and known pickup and turn-in information alongside XP, coin, and item rewards. Separate guaranteed items from pick-one options and use the native item tooltip. Show `Loading` for pending fields, `Unavailable` for inconclusive fields, and zero only for confirmed zero.

## Code and data

- The display name is **QuestChain** and the addon directory is `ForeverQuestChain`. Target the Forever client with Lua 5.1-compatible code. The TOC currently targets interface `16001` and controls the runtime load order.
- Give each UI component a matching `UI/<Component>.xml` and `UI/<Component>Mixin.lua`. Define static frames, named child regions, styling, and fixed anchors in the component?s XML. Keep shared templates in `UI/Widgets.xml`.
- Bind input handlers and received data in the mixin. Use Lua to create pooled instances and compute layouts that depend on content or viewport size. Keep quest queries, cache ownership, and game events in the data and controller layers. Load each mixin before its XML, and load templates before any other view inherits or instantiates them.
- Keep LuaRocks dependencies in the development toolchain. Declare in-game addon dependencies in the TOC and release metadata.
- `QuestData.lua` reads the public `LibQuestieDB` contract for quest records and relationships. QuestieDB is required. The full Questie addon is optional. `ForeverQuests.lua` adapts the client’s quest APIs, `QuestLog.lua` adds the Blizzard quest-log entry points, and `Core.lua` wires startup, events, and the slash command to `Controller.lua`.
- Treat upstream databases and the Forever client as the sources of truth for game data. Do not add hardcoded fallback data or local overrides for missing records, quest links, restrictions, or rewards. Keep gaps visible as missing or unavailable until the source supplies the data.
- `Chain.lua` builds the bounded quest graph and interprets prerequisites. Keep sequence links, optional lead-ins, and alternatives distinct. Show a blocker only when supported by explicit requirements and current-character state. Keep partial and cyclic data navigable.
- `Browse.lua` builds the category index on demand. Keep structural chain identities stable, and avoid merging chains that share optional links.
- `Rewards.lua` manages asynchronous reward requests and caching. Read rewards and progress from Forever. Match replies to quest IDs so a late response cannot replace the selected quest's details.
- `RewardCatalog.lua` indexes QuestieDB item-to-quest links on demand and keeps all matching source quests per item. Dungeon reward results use quests assigned to the selected dungeon. The Chain details page continues to distinguish guaranteed items and choices using client reward data.
- `Timeline.lua` computes the layout independently of the game UI. `UI/WindowMixin.lua` composes the journal views and manages routes with `Journal.lua`. `Controller.lua` supplies data and callbacks to the views.

## Verification

Do not take control of or capture the user's screen. The user runs the in-game verification.

From the repository root, run the Lua 5.1 fixtures and syntax check, then verify the TOC and XML load order.

```text
python tools/check-lua.py
python tests/runtime.py
```

For changes that affect the game UI or API behavior, include the affected flows in the manual Forever test. Use a linear chain, a fork or join, and an unaccepted quest with visible rewards as relevant. Check that repeated titles remain distinguishable, fast selection changes keep the right details, and quest status refreshes after acceptance or turn-in. Report fixture and live-client verification separately.

For local playtesting, deploy the affected runtime files under `_forever_/Interface/AddOns/ForeverQuestChain` and run `/reload`, then `/questchain`. Preserve unrelated addons and game settings. Keep editor definitions and test fixtures outside the runtime folder.
