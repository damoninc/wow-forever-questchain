# QuestChain category browsing

## Goal

Let a player find a quest chain by remembering where they picked up a quest, which dungeon it involved, or which class it was for. A player can browse with an empty search box and jump directly to the step they recognize, including a step they have yet to accept.

## Approaches

- **Quest rows.** List every matching quest as its own result. This gives direct access to a remembered step, with repeated titles and multiple steps from one chain taking separate rows.
- **Chains with matching steps.** List each chain once per category and show its matching steps under the chain heading. This groups related quests while keeping the local pickup names visible. The user chose this approach. Standalone quests appear as single rows.

## Browse flow

Add **Search** and **Browse** modes to the existing left pane. In Browse, choose **Zones**, **Dungeons**, or **Classes**, then choose a specific category. Offer **Current Zone** and **My Class** as shortcuts. Keep the category and list position when the player inspects a quest. Restore the previous Browse selection when returning from Search in the same session.

Show chain headings with their matching quests visible underneath by default. Allow a chain heading to collapse its steps. A quest row shows its title, ID, level when known, and current-character progress. List matching steps in chain order and sort groups by title, breaking ties by stable quest ID. A **Hide completed** toggle starts off. When enabled, it hides completed rows and removes groups with no remaining matches. Refresh progress on quest-log changes and preserve the visible list position where possible.

Clicking a quest opens the existing fork-and-join timeline focused on that ID and loads its normal details and rewards. The timeline covers the chain across categories and retains its completed steps. Browse is a way to find a chain, and the timeline is where the player sees the full route.

## Category membership

- **Zones** use confirmed pickup locations. A quest with a known starter in multiple zones appears in each applicable zone, once per zone. For example, a chain with a Stormwind pickup followed by a Westfall pickup appears under both zones. Each zone shows its own pickup steps. A quest that only sends the player to Westfall appears under the zone where it is offered. Normalize subzones to their parent zone. Resolve NPC and object starters using QuestieDB's location data. If the pickup zone is unavailable, include the quest under **Unknown pickup zone** and keep it searchable. Item-start quests use this group when a pickup location cannot be established.
- **Dungeons** use direct, verified dungeon assignments for the first release. A quest can be picked up in a town and still appear under its assigned dungeon. Group alternate area IDs and wings under the same canonical dungeon where the provider maps them together. Verify the initial set against Forever because the provider's instance mappings also contain other instance types and older content. Related steps appear through the timeline. Inferring dungeon membership from objective locations is a separate coverage extension.
- **Classes** use the class attached to a recognized class quest category. For other quests, use an explicit restricted class mask and group the quest under each matching class. Treat unrestricted and all-class masks as general quests. **My Class** opens the group for the current class, and the class picker supports browsing others.

QuestieDB remains the required data source. The provider exposes quest starter references, class restrictions, zone or category fields, and Forever map and instance support. Use the live client for progress and map names where available. [QuestieDB quest schema](https://github.com/Questie/QuestieDB/blob/master/src/meta/questMeta.lua) · [QuestieDB support data](https://github.com/Questie/QuestieDB/blob/master/docs/support-data.md)

## Grouping and runtime constraints

Build stable group identities once from QuestChain's quest relationships. Use the structural links already in the chain model to find each connected chain. Choose the root with the lowest quest ID as its display title and use the lowest quest ID in the component as its session key. Use stable quest ID ordering when the source has a cycle. Group by ID, including when two separate chains have identical titles. A breadcrumb or substitute can appear with its unambiguous destination chain. Opening that step keeps it selected and includes its destination chain within the existing timeline bound. Optional links preserve the identity of each structural chain.

Index categories on first use of Browse. Reuse existing quest summaries and cache starter location reads by entity. Show a loading state while building the index and keep the window responsive. Keep large lists scrollable and reachable, including categories with more entries than the Search pane's current 80-result display limit. Keep reward requests tied to the selected quest. Existing title and ID search remains available.

## Acceptance

1. Browse a zone with an empty query and find a quest by its pickup step. For a cross-zone chain, verify the local steps under each zone and the full timeline when opening either step.
2. Check a dungeon quest offered outside its dungeon and a class quest. Verify that aliases do not duplicate entries, two same-title chains stay separate, and an unrestricted quest stays out of class groups.
3. Check a standalone quest, an unknown pickup location, and a category with more than 80 entries. Toggle **Hide completed** and confirm the timeline still shows completed steps and the list retains its place while selecting quests.
4. Verify the category and grouping logic with Lua fixtures. Test the in-game Browse and Search flows in WoW: Forever, including an unaccepted quest with visible rewards.
