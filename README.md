# QuestChain for WoW: Forever

QuestChain is an in-game quest-chain reference for **WoW: Forever**. Look up a quest before accepting it to see where the chain starts, what unlocks the next step, and what the chain offers. Follow your character's progress and inspect XP, coin, and item rewards without leaving the game.

## Install

1. Install or enable the Forever version of [QuestieDB](https://github.com/Questie/QuestieDB/releases). A compatible QuestieDB installation from Questie also works.
2. Download the installable ZIP from [GitHub Releases](https://github.com/damoninc/wow-forever-questchain/releases) and extract it into your Forever client's `Interface/AddOns` directory. The ZIP contains the `ForeverQuestChain` folder. For a source checkout, copy that folder from this repository instead.
3. Enable **QuestChain** in the AddOns list. Click the book icon by the minimap or run `/questchain` in chat. Drag the icon to move it. If the new addon is absent from the AddOns list, restart the client.

Search by title or quest ID. Linear steps run down the center of the timeline. Sibling branches sit side by side and reconnect at their shared next step. Hold **Shift** while scrolling to pan wide branches.

Right-click a quest in WoW's Quest Log and choose **Open in QuestChain** to jump to its step. The quest details page also has an **Open in QuestChain** button beside **Back**.

**Active Chains** shows each known chain with a quest in your log once. Selecting a chain opens a step ready to turn in when one is available. Use **Back** to return to the list.

Use the breadcrumbs above the timeline to go back to Browse or reopen the current zone, dungeon, or class list. The trail keeps the category you opened the chain from. When opening from the quest log, it uses the selected quest's known category. A verified dungeon assignment takes priority over the pickup zone. **Earlier quests** jumps to a preceding step in the current chain.

Open the **Browse** tab to search by name or ID, or choose **By category** for **Zones**, **Dungeons**, and **Classes**. Zone results follow pickup locations, so a chain can appear in several zones with different steps under each. **Current Zone**, **My Class**, and **Hide completed** help narrow the list. Selecting a quest opens the **Chain** tab at that step. Return to **Browse** to resume from the same list position.

The **Quest log** column in Search and By category shows **In progress**, **Ready to turn in**, **Completed**, or **Not in log** for your current character.

Search results and timeline cards show how many party members currently have that quest in their log. Hover the row or card for names. Party members can appear without installing QuestChain.

In **By category**, choose **Show completed** to find finished quests in the selected zone, dungeon, or class. **Show all** clears the filter.

In category browsing, chain rows come first, followed by standalone quests. Each group sorts by level, lowest first, with unknown levels at the end. A chain uses its lowest known quest level and shows progress for the steps in that category. Click it to open the timeline at a relevant step. A partly finished chain can appear under **Show completed**, which opens it at a completed step. Search results sort by quest level.

Zone and dungeon pickers also sort by level and show a range when available. Ranges come from the game map when it supplies them, or from the category's quest levels. Dungeon chains include linked steps outside the instance when opened.

Open **Rewards** to browse items awarded by quests in a zone or dungeon. Search by item name or ID and hover an item for its tooltip. Choose a source quest to open its chain, then return to **Rewards** to resume browsing. The list uses item-to-quest links available in QuestieDB.

In **Quest Details**, select **Show on map** under a pickup or turn-in location with known coordinates. The action opens the zone map and adds a TomTom waypoint if TomTom is enabled. Otherwise QuestChain marks the location until you close the world map. Use `/questchain` to return to the selected quest.

Select a step to see its objectives, prerequisites, pickup and turn-in information, and rewards. Guaranteed items and pick-one rewards appear separately. Hover an item for its tooltip. **Unavailable** means the client could not supply a confirmed value for that field.

## Test in Forever

- Search a repeated title such as **The Defias Brotherhood**, open a result, and click a different timeline step.
- Look up a branch or join such as **Big Game Hunter** (`208`) and a Forever-original quest. Follow the connectors and check the requirements.
- Compare the panel with Blizzard's quest offer for a quest that awards coin or choice items. Switch quests quickly and verify that the reward details follow your selection.
- Accept or turn in a quest in the displayed chain and check that its status changes.

Run the Lua 5.1 fixtures in `tests/` from the repository root. See [AGENTS.md](AGENTS.md) for the product goals and development guide.

## Publishing

**Every push or merge to `main` automatically publishes a stable Release to GitHub and CurseForge after the checks pass.** Pull requests run the checks without publishing. Merge changes when they are ready for players.

The single **CI and deploy** workflow runs the Lua fixtures and real packaging tests, assigns the next patch version (for example `v1.0.0` to `v1.0.1`), and tags the merged commit itself. There is no release button, version-bump commit, or manual TOC edit. Releases are queued rather than cancelled when more merges arrive.

The Git tag is the version source. `## Version: @project-version@` in the source TOC is filled by the pinned BigWigs packager. One publishing invocation builds one installable ZIP and uploads that same file to GitHub and CurseForge as Release. GitHub also receives the Forever `release.json` manifest used by addon managers.

Each release includes `curseforge-upload.json`: the accepted CurseForge file ID, source commit, archive name, stable release type, and ZIP checksum. CI downloads the GitHub ZIP and verifies it against this checksum. The deployment summary links the GitHub release and identifies the CurseForge file.

The CurseForge project ID is `1792071`, recorded in the TOC as `X-Curse-Project-ID`. The repository needs the `CF_API_TOKEN` Actions secret. GitHub uses its built-in token; no extra access token is required. QuestieDB is a required CurseForge dependency and TomTom is optional. GitHub/manual users must install QuestieDB separately.

A completed deployment rerun verifies its existing release. A failed or ambiguous CurseForge upload stops without automatically repeating the POST; inspect the retained deployment files before retrying so an accepted file is not uploaded twice. Released tags remain immutable. A new merge gets a new version.

CurseForge can moderate and index files after accepting the upload. The project must be non-Experimental and its file tagged for Forever for app discovery. GitHub releases provide the package and metadata for WowUp; Hub indexing is managed externally.

## Editor IntelliSense

Open the repository root in VS Code with the [Lua extension](https://marketplace.visualstudio.com/items?itemName=sumneko.lua). From the repository root, run `pwsh -File ./tools/setup-intellisense.ps1`. If your game is installed elsewhere, pass the QuestieDB addon directory with `-QuestieDBPath`. Then reload the editor window.

Hover an API in the addon source for parameters and return types, or type `C_QuestLog.` for completions. LuaLS reads the [Forever client export](https://github.com/Atraeau/WoW-Addons/blob/1b8fa2898e15d20dfbffdcdaf6264df3d708f225/types/WowForeverAPI.lua), [shared FrameXML types](https://github.com/Ketho/vscode-wow-api/tree/0.22.3/Annotations/Core/Widget), and QuestieDB's shipped declarations. The Forever export is from build 70790. Some legacy signatures live in `types/wow-forever-globals.lua`.
