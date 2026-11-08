# QuestChain Implementation Plan

> **For agentic workers.** Use superpowers:executing-plans for inline implementation or superpowers:subagent-driven-development if the user chooses delegation. Track the steps with checkboxes.

**Goal** Build an installable WoW: Forever addon that lets a player search for a quest, follow its chain, and inspect objectives and rewards in-game.

**Architecture** A QuestieDB adapter supplies quest records to a chain and search model. A separate client adapter reads character state and loads rewards on selection. A native WoW window renders these models and exposes selection callbacks.

**Tech stack** WoW Lua and FrameXML, QuestieDB public API, Lua 5.1-compatible assertion tests, and PowerShell for packaging.

**Spec** [QuestChain for WoW: Forever](../specs/2026-11-07-questchain-design.md)

## Global Constraints

- Target **WoW: Forever**. The installed client is `1.60.1.70862` and the installed Forever TOC uses interface `16001`. Use the internal addon name `ForeverQuestChain`, display title **QuestChain**, and command `/questchain`.
- Require **QuestieDB** and check `LibQuestieDB.RequireContract(1)` before reading data. The installed QuestieDB `1.0.11` advertises contract `4` and accepts contract `1`. The full Questie addon is optional. [QuestieDB public API](https://github.com/Questie/QuestieDB/blob/master/docs/api.md)
- Use the live client for rewards and current-character progress. Keep `Loading`, `Unavailable`, and confirmed zero distinct. Include XP, coin, guaranteed items, and choose-one items.
- The first build uses a movable, vertical timeline window. Search covers title and exact quest ID. Map waypoints, quest-log shortcuts, guild progress, gear recommendations, additional reward types, and chain totals are follow-up work.
- The workspace contains the spec and plan and needs Git initialization before local commits. Establish the local baseline when implementation starts. Set `$qcLua` to the absolute path of a Lua 5.1-compatible interpreter and verify it with `& $qcLua -v`. QuestieDB's development tools include a Windows build if needed. [QuestieDB Lua runner](https://github.com/Questie/QuestieDB/tree/master/tools/lua-binary)

## Review Focus

- A zero coin result on a future quest with inconclusive data shows **Unavailable**. A verified zero still shows zero. See Task 3.
- A late response after selecting a different quest updates the cache for the original quest and leaves the visible detail panel on the current quest. See Task 3.
- A group prerequisite with a completed exclusive alternative is satisfied for a positive entry and unsatisfied for a negative entry unless that exact quest is complete. See Task 2.
- Identical titles return distinct quest IDs and a numeric query selects only that ID. See Task 2.
- A missing quest record or circular source link leaves the rest of the timeline navigable and never creates a false blocker. See Tasks 2 and 4.

## Files and ownership

| Path | Responsibility |
| --- | --- |
| `ForeverQuestChain/ForeverQuestChain.toc` | Target interface, title, required dependency, and load order |
| `ForeverQuestChain/QuestData.lua` | QuestieDB contract check and normalized data reads |
| `ForeverQuestChain/Chain.lua` | Search index, bounded graph, and prerequisite status |
| `ForeverQuestChain/Rewards.lua` | Selected-quest reward requests, cache, and display state |
| `ForeverQuestChain/Window.lua` | Native frames, search results, timeline, details, and item tooltips |
| `ForeverQuestChain/Core.lua` | Slash command, client API wrappers, and event wiring |
| `tests/chain.lua`, `tests/rewards.lua` | Lua assertions with fixtures for graph and reward behavior |
| `README.md` | Installation, command, and live verification checklist |

Each Lua file registers its module on the addon's private namespace received through `local _, ns = ...`. Tests load the pure modules with `assert(loadfile(path))("ForeverQuestChain", ns)` using a plain table for `ns`. The TOC loads QuestData, Chain, Rewards, Window, then Core.

## Task 1 — Confirm the live data contract

**Files** Record results in this task. Use the installed client and the existing QuestieDB dependency.

The tester confirmed the live checks in Forever. The initial XP and item count are recorded below. The follow-up quest IDs, payout, and readiness output are available for recapture if coverage differs in the installed addon.

- [ ] Print the client and provider versions in chat with `/run print(GetBuildInfo())` and `/run print(LibQuestieDB and LibQuestieDB.contractVersion)`. Expect interface `16001` and a provider contract that accepts `1`. Resolve mismatches before packaging.
- [ ] Probe the title and prerequisite fields through `LibQuestieDB.Quest.Get`. Candidate cases are **The Defias Brotherhood** `166` or **Returning the Lost Satchel** `5724` for a sequence, **Kaela's Update** `1091` or **Big Game Hunter** `208` for an all-required join, and a Forever-original quest from the tester’s current zone. Confirm the installed provider's relationships and record the actual quest IDs tested.
- [ ] Request the quest used in the 6,200 XP probe with `C_QuestLog.RequestLoadQuestByID`. Use the actual ID from the tester in the following commands. The examples use `166`.

  ```lua
  /run local q=166; print("Reward data ready",HaveQuestRewardData and HaveQuestRewardData(q),"XP",GetQuestLogRewardXP(q),"Copper",GetQuestLogRewardMoney(q))
  /run local q=166; for i=1,GetNumQuestLogChoices(q) do print(i,GetQuestLogChoiceInfo(i,q)) end
  ```

- [ ] Repeat the readiness and amount probe for a quest whose offer shows a nonzero coin reward. Compare the output before opening the offer, at the offer, and after acceptance when the tester can accept it. Check a known zero-coin quest as a control. Use the results to determine which readiness signal supports a confirmed zero for future quests. Check item IDs and names on the choice rows. Keep any unproven field unavailable in the build.
- [ ] Record the observations for Task 3, including the known-paying quest, matching coin amount or discrepancy, item IDs, and reward-readiness behavior. The first result already recorded was `6200 XP / 0 copper / 0 guaranteed / 3 choices`. [Forever quest API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua) · [Forever reward tooltip code](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua#L702)

## Task 2 — Quest data, search, and chain projection

**Files** `ForeverQuestChain/QuestData.lua`, `ForeverQuestChain/Chain.lua`, `tests/chain.lua`.

**Produces**

- `ns.QuestData.New(lib) -> source | nil, reason`. The source has `ids() -> number[]` and `read(id) -> Quest | nil`. A `Quest` has `id`, `title`, optional `level`, `minLevel`, `zone`, `objectives` as text lines, `starters` and `finishers` as lists of named locations, and normalized `anyOf`, `allOf`, `exclusiveTo`, `successors`, and `breadcrumbs` as ID lists. Preserve signed entries in `allOf`. Each location has `name` and optional `zone`, `x`, and `y`.
- `ns.Chain.New(source) -> model`. The model exposes `Search(query) -> Quest[]`, `GetQuest(id) -> Quest | nil`, `Build(focusId, limit) -> ChainView | nil`, and `Status(id, player, view) -> status, reason?`. `player` supplies `level`, `isActive(id)`, `isReady(id)`, and `isCompleted(id)`. Status values are `ready`, `active`, `completed`, `blocked`, and `unstarted`.
- A `ChainView` has `focusId`, ordered `quests`, `edges`, `missingIds`, `omittedIds`, and `uncertainIds`. Edges have `fromId`, `toId`, and `kind`, one of `sequence`, `all`, `any`, `breadcrumb`, and `substitute`. A substitute edge shows an exclusive alternative that satisfies a positive group prerequisite. `uncertainIds` is a set keyed by quest ID. Other ID fields are ordered arrays.

- [ ] Write `tests/chain.lua` with a fake provider and assertions. Build an ordinary fork `1 → 2` and `1 → 3`, with `2 + 3 → 4` as all-required and `2 or 3 → 5` as any-one. Give IDs 2 and 3 the title `Twin` and make 6 exclusive with 2. Assert:

  ```lua
  assert(#model:Search("twin") == 2)
  assert(#model:Search("3") == 1 and model:Search("3")[1].id == 3)
  assert(model:Build(999) == nil)
  assert(view.focusId == 2 and #view.quests == 6)
  assert(view.edges[1].fromId == 1)
  assert(model:Status(4, onlyTwoComplete, view) == "blocked")
  assert(model:Status(5, onlyTwoComplete, view) == "unstarted")
  assert(model:Status(4, threeAndSixComplete, view) == "unstarted")
  assert(signedModel:Status(4, threeAndSixComplete, signedView) == "blocked")
  assert(brokenView.missingIds[1] == 999 and brokenView.uncertainIds[4])
  assert(brokenModel:Status(4, noneComplete, brokenView) == "unstarted")
  assert(#limitedView.quests == 3 and #limitedView.omittedIds > 0)
  ```

  Check the substitute edge from 6 to 4. The signed fixture changes `allOf` for 4 to `{-2, 3}` and has five visible quests. The broken fixture adds a cycle between 2 and 4 and a missing prerequisite 999 for 4. Also exercise a single unlinked quest and active/ready status precedence for a repeatable quest already flagged completed.
- [ ] Run `& $qcLua tests/chain.lua`. Expect failure because the modules do not exist yet.
- [ ] Implement `QuestData.New` using the composed public reads. Resolve starter and finisher names from NPC, object, and item IDs. Include a location when the provider can identify it clearly, otherwise show the name. Normalize provider zero sentinels to absent optional values. Index title and relationship fields on first use and resolve detail-only fields for displayed quests as needed.
- [ ] Implement `Chain.New` and its four methods. Search trims whitespace, treats digits-only input as an exact ID, and uses plain case-insensitive substring matching for titles. Return exact title matches first, then sort by title and ID. An empty query returns no rows.
- [ ] Build the known connected chain around the focus through sequence and prerequisite links in both directions so that starting at a middle step still includes sibling branches. Include adjacent optional breadcrumbs separately. Use a default cap of 100 known quests with stable traversal and topological ordering. Keep order deterministic for broken links and cycles, include each known quest once, and mark affected requirements uncertain. Sort edges deterministically by source order, target order, and kind. If the same pair has a sequence edge and a prerequisite edge, render the prerequisite edge once.
- [ ] For an active quest, check ready first and otherwise show active. For other quests, check completed first, then confirmed blockers such as minimum level and unmet known prerequisites, then unstarted. Keep conflicting, cyclic, and missing prerequisite data from producing a false blocker. Respect Questie’s signed group entries and exclusive alternatives as described in the spec. Use explicit prerequisite data for blockers. [Questie eligibility source](https://github.com/Questie/Questie/blob/master/Database/QuestieDB.lua)
- [ ] Run `& $qcLua tests/chain.lua`. Expect exit code `0` and `chain tests passed`. Commit the three owned files together.

## Task 3 — Live rewards

**Files** `ForeverQuestChain/Rewards.lua`, `tests/rewards.lua`.

**Produces** `ns.Rewards.New(api, onUpdate) -> rewards`. Methods are `Select(id) -> RewardView`, `Get(id) -> RewardView`, `OnQuestDataLoaded(id, success)`, and `Invalidate(id?)`. The callback is `onUpdate(id, view)`. The injected API supplies `request(id)`, `after(seconds, callback)`, and `read(id, loadSucceeded) -> RewardView | nil` with the readiness rules from Task 1. The reader returns nil if data is still pending. A `RewardView` has `xp`, `copper`, `guaranteed`, and `choices` fields, each shaped as `{ state, value? }`. The states are `loading`, `known`, and `unavailable`. Each item is `{ id, name?, icon?, quantity, link? }`.

- [ ] Write `tests/rewards.lua` with a fake request queue, clock, and reader. Select quest 166, then select quest 5724. Deliver the response for 166 first, then the response for 5724, using fixtures with known 6,200 XP, unavailable coin for 166, and confirmed zero coin for 5724. Assert:

  ```lua
  assert(initial.xp.state == "loading")
  assert(requests[1] == 166 and requests[2] == 5724 and #requests == 2)
  assert(rewards:Get(166).xp.value == 6200)
  assert(rewards:Get(166).copper.state == "unavailable")
  assert(rewards:Get(5724).copper.state == "known")
  assert(rewards:Get(5724).copper.value == 0)
  assert(#delivered == 1 and delivered[1] == 5724)
  ```

  Include cases for a duplicate selection while pending, a failed event, a timeout followed by reselection, and invalidation followed by a fresh read.
- [ ] Run `& $qcLua tests/rewards.lua`. Expect failure because Rewards.lua does not exist yet.
- [ ] Implement the four methods. Read already-loaded data on selection when readiness can be determined without an event. Request only when selection needs data, deduplicate pending requests per ID, and bound the wait at three seconds. Keep a session cache keyed by quest ID. Publish asynchronous updates only for the selected ID. After a failed or timed-out request, allow retry on reselection. Invalidation clears stale fields and rereads the selected quest when affected.
- [ ] Run `& $qcLua tests/rewards.lua`. Expect exit code `0` and `reward tests passed`. Commit the two owned files together.

## Task 4 — Timeline and details window

**Files** `ForeverQuestChain/Window.lua`.

**Consumes** `Quest`, `ChainView`, statuses, and `RewardView` from Tasks 2 and 3. This task can use fixtures with those shapes.

**Produces** `ns.Window.New(callbacks) -> window`. Callbacks are `search(query)`, `openQuest(id)` to focus a search result or omitted quest, and `selectStep(id)` to select inside the displayed view. Methods are `Toggle()`, `ShowResults(results, message?)`, `ShowChain(view, selectedId, statusesById, scrollToId?)`, and `ShowDetails(quest, rewards)`. Status entries are `{ status, reason? }`.

- [ ] Write down the fixture checks before coding. Search for `Twin` and expect distinct rows for IDs 2 and 3. Open a chain at ID 3 and expect that quest selected and visible. Click a different row and expect the scroll position preserved. Confirm the all and any joins, a missing-link notice, an omitted quest link that opens its own focus, and independent reward states on the details panel.
- [ ] Implement the native window with a search box, scrollable results and timeline, and a readable detail panel. Use connected rows and indented branch paths. Label joins **All required** or **Any one required** and visually separate breadcrumbs. Use icons plus text for progress. When optional data is missing, keep other quest details visible. Make the window movable, closeable, and usable at standard UI scale.
- [ ] Render XP and formatted coin, then guaranteed and pick-one rewards in separate sections. Show `Loading` and `Unavailable` per field. Show a standard item tooltip using the available item link or ID. Ensure empty known item lists read as no items of that kind.
- [ ] Run the window checks in Forever against real chains after composition in Task 5. Use the Task 2 and 3 fixtures to verify graph and reward cases that the test character cannot reproduce. Include the window change in its own commit.

## Task 5 — Compose, package, and verify in Forever

**Files** `ForeverQuestChain/ForeverQuestChain.toc`, `ForeverQuestChain/Core.lua`, `README.md`.

**Consumes** the provider, model, rewards, and window interfaces above. The TOC entry point loads `Core.lua` last.

- [ ] Add the TOC using interface `16001`, title `QuestChain`, version `0.1.0`, and `## Dependencies: QuestieDB`. Register `/questchain` when the addon loads and print the startup error if the provider contract check fails.
- [ ] Compose the slash command and callbacks. Opening a search result builds its chain, selects it, and scrolls to it. Step selection keeps the same chain and scroll position while it refreshes rewards. Provide an explicit empty-results message and keep the prior selection usable after a miss. For active and completed status, use `C_QuestLog.IsOnQuest`, `ReadyForTurnIn`, and `IsQuestFlaggedCompleted`. On a quest-log update, refresh displayed statuses. Refresh level-dependent state on `PLAYER_LEVEL_UP`, and invalidate affected reward reads on acceptance and turn-in.
- [ ] Wire `QUEST_DATA_LOAD_RESULT` to the rewards model. Implement its client reader using the verified XP, coin, reward count, choice count, and item APIs from Task 1. Treat zero as known only with verified readiness. Request item data if a reward ID is known and tooltip information is pending. Refresh the current detail panel for that item only if it still belongs to the selected quest.
- [ ] Document installing the zip under the Forever client's `Interface/AddOns` folder, enabling QuestieDB, and running `/questchain`.
- [ ] Run `& $qcLua tests/chain.lua` and `& $qcLua tests/rewards.lua`. Expect both to exit `0`. Check that every shipped Lua file parses with the following command and expect exit `0`.

  ```powershell
  & $qcLua -e 'for _,name in ipairs({"QuestData","Chain","Rewards","Window","Core"}) do assert(loadfile("ForeverQuestChain/"..name..".lua")) end'
  ```
- [ ] Package only the addon folder with `Compress-Archive -LiteralPath .\ForeverQuestChain -DestinationPath (Join-Path $env:TEMP 'QuestChain-0.1.0-test.zip') -Force`. Inspect the zip and verify the TOC and all five Lua modules sit inside a single `ForeverQuestChain` directory.
- [ ] Install or hand off the zip for the in-game pass. Check a linear chain, a real branch, and a Forever-original chain. Search for a duplicate title, select a future step, and compare the verified XP, coin, and items with the Blizzard quest window. Hover an item, accept or turn in a quest, and switch rapidly between two quests. Verify live status changes, no stale rewards, and no Lua errors. If reward coverage differs from Task 1, record the gap and resolve it or agree on the scope before calling the feature ready. Commit the integration and README.

## Execution split

Run Task 1 together with the live tester. Tasks 2 and 3 own separate files and can proceed independently once the interfaces and reward observations are settled. Task 4 can proceed against fixtures for those same interfaces. Task 5 integrates the pieces and produces the playable zip. For this first build, inline execution keeps the live checks and integration close together. If delegation is preferred, give one implementer Tasks 2–3 and another Task 4 after the probe.
