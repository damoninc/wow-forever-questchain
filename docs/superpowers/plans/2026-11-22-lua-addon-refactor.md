# Lua addon refactor plan

Preserve QuestChain’s existing journal, quest and reward presentation, and release packaging. Keep quest, browse, reward cache, and timeline calculations in their existing data modules.

1. Establish the Lua 5.1 baseline. Add a local and CI check command and pin Luacheck through LuaRocks. Scope the linter to the shipped Lua code and tell it which globals Forever supplies. Keep development files outside the addon and its release ZIP.
2. Pair each view's XML with its Lua mixin inside the owning feature under `ForeverQuestChain/UI/`. The journal shell composes its pages. Chain and location views live in their respective journal folders, and the quest list and journal widgets stay at the journal level. Keep the minimap, world map, and Blizzard quest-log integration in their own folders. Each view owns its static layout, row pool, and rendering behavior, and receives data and actions from the controller.
3. Move Forever quest API reads and Blizzard quest-log entry points out of the application controller. Keep `Core.lua` responsible for startup, slash commands, and event registration. Preserve the event order and the quest-ID checks on asynchronous rewards.
4. Verify the TOC, XML templates, and release boundary alongside the existing fixtures. Exercise journal navigation, timeline selection, rewards, and resizing in Forever. Check the packaged ZIP with the existing BigWigs tests.
