# QuestChain for WoW: Forever

## Goal

A player can find any quest in the supported database, see where it sits in a chain, and check the work and rewards ahead without leaving the game. Use Attune’s connected steps and progress markers and MyTools Questool’s quest search and detail view as interaction references. [Attune](https://www.curseforge.com/wow/addons/attune) · [MyTools Questool](https://www.curseforge.com/wow/addons/mytools-questool)

## Approaches

- **QuestieDB and live reward data.** Use the standalone QuestieDB addon for search, quest relationships, objectives, and start and end records. Use Forever for character progress and rewards. The user chose this approach. It gives the first release broad quest coverage with one dependency and lets the player reuse the QuestieDB installation that ships with Questie. [QuestieDB public API](https://github.com/Questie/QuestieDB/blob/master/docs/api.md) · [QuestieDB releases](https://github.com/Questie/QuestieDB/releases)
- **Bundled quest database.** Ship and maintain our own quest and reward snapshot. This gives players a standalone install and lets us supply verified fallback values if the game cannot preview a reward. Each snapshot would need coverage checks and updates as Forever changes. Revisit this if the live coin and item checks expose gaps that affect common chains.

## First playable version

Open a movable addon window with `/questchain`. Search by quest title or exact ID, including quests outside the log. Show each matching quest’s title, ID, and level or zone when known so repeated titles can be distinguished. Select a result to open its timeline with that step selected and scrolled into view. Clicking steps in the timeline changes the detail panel and preserves the view.

Use a top-to-bottom fork-and-join timeline. Center ordinary steps, place sibling paths side by side, and connect them where they split and rejoin. Label joins **All required** or **Any one required** according to the prerequisite data. Scroll vertically to browse long chains and hold Shift while scrolling to pan wide branches. Mark completed, ready to turn in, in progress, blocked by a known requirement, and unstarted quests with icons and text. Mark the selected quest separately. “Unstarted” makes no claim about eligibility.

The selected quest’s detail panel shows the objective, quest ID and level, known prerequisites, who or what starts and ends the quest, and a zone or coordinates when known. Keep the reward section easy to scan. Show XP and the coin reward, formatted in gold, silver, and copper. Separate guaranteed items from pick-one options. Hovering an item shows its standard game tooltip. The first version covers XP, coin, and item rewards. Map waypoints, quest-log shortcuts, additional reward types, guild progress, gear recommendations, and chain totals are follow-up work.

## Quest relationships and character state

- Target the WoW: Forever client with a native Lua addon. Declare QuestieDB as a required addon and verify the public API contract at startup. Read through a small adapter using `LibQuestieDB`. The Questie tracker and map UI are optional.
- Index quest titles and reverse links so a search can start in the middle of a chain. Begin with the selected quest, walk its known ancestors and successors, and include prerequisite alternatives needed to explain displayed joins. Search still works for single quests and disconnected records. Keep traversal bounded and deterministic, deduplicate IDs, and show when source links are missing or the view reaches its limit. Provide a way to open a limited-out quest as the focus when its ID is known.
- Keep sequence links, mandatory prerequisites, alternative prerequisites, and optional breadcrumbs distinct. Sequence links help navigate and require separate prerequisite evidence to justify a blocker. Questie evaluates the single-prerequisite list as any one and the group list as all. Each positive entry in a group may also be satisfied by completing one of its exclusive alternatives. A negative entry requires completing the quest identified by its absolute ID. If a row supplies conflicting requirement data, show the links without making a definitive unlock claim until the semantics have been checked. Cross-check requirements with Questie before displaying a quest as blocked. [Questie quest eligibility code](https://github.com/Questie/Questie/blob/master/Database/QuestieDB.lua)
- Read completion, active status, and readiness from the current character’s quest log. Refresh on quest-log changes. Show confirmed blockers such as a missing required step or minimum level. Keep deeper eligibility rules, including professions and events, outside the first release’s status calculation. [Forever quest-log API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua)

## Rewards

The user’s live probe for an unaccepted quest returned 6,200 XP, zero copper, zero guaranteed items, and three item choices. The choice count is confirmed for that quest. The item names, tooltip rendering, and meaning of zero copper still need checking.

Request data by quest ID for the selected step. Use the quest data load event and update the detail pane only if its selection still matches the response. Cache successful reads for the session as appropriate and refresh character-dependent values after relevant character or quest changes. Use `Loading` while a request is pending, `Unavailable` for a failed or inconclusive field, and zero only for a confirmed zero. Keep the rest of the quest visible if reward data is incomplete. If the client gives no reliable signal that a zero reward is loaded for a future quest, show `Unavailable` for that field. [Forever quest-log API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua) · [Forever reward tooltip code](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/QuestUtils.lua#L702)

## Build and live test milestones

1. **Data check.** Confirm the installed Forever interface number and QuestieDB release contract. Verify lookup and relationship fields for a linear chain, a real branch or join, and a Forever-original chain. Inspect the names of all three reward choices from the probe. Compare a quest with a known coin reward to the Blizzard quest window before and after acceptance. This decides whether future coin can be displayed immediately and gives the UI a concrete data contract.
2. **Playable timeline.** Wire the real data into search, the timeline, and the details. Package a test install with the required dependency and instructions for the Forever client. Use fixtures for prerequisite joins, duplicate names, missing links, and cycles. Check that quickly switching quests never shows the previous quest’s reward.
3. **In-game acceptance.** A player can find the start, follow the branch, and inspect a future quest’s rewards. Validate live progress by accepting or turning in a quest, compare reward amounts and item tooltips to Blizzard’s UI, and check that an unknown quest or missing reward has a clear state. If coin or item previews have material gaps on the sample quests, resolve the gap or agree on the coverage before treating the reward feature as ready.

## Project decisions

The working display name is **QuestChain**. A Forever addon already uses that display name on CurseForge. Use a distinct internal folder name, `ForeverQuestChain`, for the test build and settle the public listing name separately if this is a different project. [Existing CurseForge listing](https://www.curseforge.com/wow/addons/questchain)

Keep the first live data check with one implementer. Once the input and output fields are settled, the quest and reward logic and the timeline and details UI can proceed in parallel against shared fixtures. Integrate them before packaging and have the user test the result in Forever.
