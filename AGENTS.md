# QuestChain development guide

## Product purpose

QuestChain is an in-game quest-chain reference for **World of Warcraft: Forever**. Its job is to let players answer three questions without leaving the game, including before they accept a quest.

- Where does this quest fit in the chain, and what have I already done?
- What comes next, and which prerequisites or alternate routes matter?
- What are the objectives, pickup and turn-in locations, and rewards for this step?

Keep the path from search to an answer short. Prioritize a readable timeline, accurate character progress, and reliable previews of XP, coin, and item rewards.

## Player experience

- `/questchain` opens the addon. Search by quest name or exact ID, including quests outside the current log. Use quest IDs internally and show enough context to distinguish duplicate titles.
- Browse groups quests by chain under pickup zone, verified dungeon assignment, or class. A cross-zone chain can appear in each zone with the steps picked up there. Selecting a Browse result opens the timeline at that step.
- The Adventure Guide window uses persistent Browse and Chain tabs. Browse fills the window body and offers Search and By category. Keep filters and page controls outside the scrolling results, and preserve the catalog's mode and position while viewing a chain. The Chain page gives the timeline most of the space and keeps quest details on the right.
- The approved timeline runs top to bottom. Center linear steps, place sibling steps side by side, and draw connectors where paths split or rejoin. Label all-required and any-one-required joins. Keep cards readable on wide forks and support horizontal panning with Shift + mouse wheel.
- Selecting a search result brings its step into view. Clicking a step within the chain updates the detail panel and preserves the scroll position. Mark the selected step separately from progress, and use text as well as color for quest status.
- Show objectives and known pickup and turn-in information alongside XP, coin, and item rewards. Separate guaranteed items from pick-one options and use the native item tooltip. Show `Loading` for pending fields, `Unavailable` for inconclusive fields, and zero only for confirmed zero.

## Code and data

- The display name is **QuestChain** and the addon directory is `ForeverQuestChain`. Target the Forever client with Lua 5.1-compatible code. The TOC currently targets interface `16001` and controls the runtime load order.
- `QuestData.lua` reads the public `LibQuestieDB` contract for quest records and relationships. QuestieDB is required. The full Questie addon is optional. `Core.lua` wires the client APIs, events, and slash command.
- `Chain.lua` builds the bounded quest graph and interprets prerequisites. Keep sequence links, optional lead-ins, and alternatives distinct. Show a blocker only when supported by explicit requirements and current-character state. Keep partial and cyclic data navigable.
- `Browse.lua` builds the category index on demand. Keep structural chain identities stable, and avoid merging chains that share optional links.
- `Rewards.lua` manages asynchronous reward requests and caching. Read rewards and progress from Forever. Match replies to quest IDs so a late response cannot replace the selected quest's details.
- `Timeline.lua` computes the layout independently of the game UI. `Window.lua` renders native frames and handles interaction. Browser mockups use sample data and help compare designs. Verify shipped behavior in Forever.

## Verification

Run the Lua 5.1-compatible fixture suites from the repository root.

```text
lua tests/chain.lua
lua tests/rewards.lua
lua tests/timeline.lua
lua tests/browse.lua
```

For changes that affect the game UI or API behavior, also test the affected flow in Forever. Use a linear chain, a fork or join, and an unaccepted quest with visible rewards as relevant. Check that repeated titles remain distinguishable, fast selection changes keep the right details, and quest status refreshes after acceptance or turn-in. Report fixture and live-client verification separately.

For local playtesting, deploy the affected runtime files under `_forever_/Interface/AddOns/ForeverQuestChain` and run `/reload`, then `/questchain`. Preserve unrelated addons and game settings. Keep editor definitions and test fixtures outside the runtime folder.
