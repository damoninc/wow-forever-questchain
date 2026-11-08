# QuestChain for WoW: Forever

QuestChain is an in-game quest-chain reference for **WoW: Forever**. Look up a quest before accepting it to see where the chain starts, what unlocks the next step, and what the chain offers. Follow your character's progress and inspect XP, coin, and item rewards without leaving the game.

## Install

1. Install or enable the Forever version of [QuestieDB](https://github.com/Questie/QuestieDB/releases). A compatible QuestieDB installation from Questie also works.
2. Clone this repository or download it via **Code → Download ZIP**. Copy the `ForeverQuestChain` folder into your Forever client's `Interface/AddOns` directory.
3. Enable **QuestChain** in the AddOns list and run `/questchain` in chat. Use `/reload` if you added it during a session. If the new addon is absent from the AddOns list, restart the client.

Search by title or quest ID. Linear steps run down the center of the timeline. Sibling branches sit side by side and reconnect at their shared next step. Hold **Shift** while scrolling to pan wide branches.

Open the **Browse** tab to search by name or ID, or choose **By category** for **Zones**, **Dungeons**, and **Classes**. Zone results follow pickup locations, so a chain can appear in several zones with different steps under each. **Current Zone**, **My Class**, and **Hide completed** help narrow the list. Selecting a quest opens the **Chain** tab at that step. Return to **Browse** to resume from the same list position.

In **Quest Details**, select **Show on map** under a pickup or turn-in location with known coordinates. The action opens the zone map and adds a TomTom waypoint if TomTom is enabled. Otherwise QuestChain marks the location until you close the world map. Use `/questchain` to return to the selected quest.

Select a step to see its objectives, prerequisites, pickup and turn-in information, and rewards. Guaranteed items and pick-one rewards appear separately. Hover an item for its tooltip. **Unavailable** means the client could not supply a confirmed value for that field.

## Test in Forever

- Search a repeated title such as **The Defias Brotherhood**, open a result, and click a different timeline step.
- Look up a branch or join such as **Big Game Hunter** (`208`) and a Forever-original quest. Follow the connectors and check the requirements.
- Compare the panel with Blizzard's quest offer for a quest that awards coin or choice items. Switch quests quickly and verify that the reward details follow your selection.
- Accept or turn in a quest in the displayed chain and check that its status changes.

Run `lua tests/chain.lua`, `lua tests/rewards.lua`, `lua tests/timeline.lua`, and `lua tests/browse.lua` from the repository root with Lua 5.1. See [AGENTS.md](AGENTS.md) for the product goals and development guide.

## Editor IntelliSense

Open the repository root in VS Code with the [Lua extension](https://marketplace.visualstudio.com/items?itemName=sumneko.lua). From the repository root, run `pwsh -File ./tools/setup-intellisense.ps1`. If your game is installed elsewhere, pass the QuestieDB addon directory with `-QuestieDBPath`. Then reload the editor window.

Hover an API in the addon source for parameters and return types, or type `C_QuestLog.` for completions. LuaLS reads the [Forever client export](https://github.com/Atraeau/WoW-Addons/blob/1b8fa2898e15d20dfbffdcdaf6264df3d708f225/types/WowForeverAPI.lua), [shared FrameXML types](https://github.com/Ketho/vscode-wow-api/tree/0.22.3/Annotations/Core/Widget), and QuestieDB's shipped declarations. The Forever export is from build 70790. Some legacy signatures live in `types/wow-forever-globals.lua`.
