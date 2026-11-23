# QuestChain for WoW: Forever

QuestChain is an in-game quest-chain reference for **WoW: Forever**. Look up a quest before accepting it to see where the chain starts, what unlocks the next step, and what the chain offers. Follow your character's progress and inspect XP, coin, and item rewards without leaving the game.

## Install

1. Install or enable the Forever version of [QuestieDB](https://github.com/Questie/QuestieDB/releases). A compatible QuestieDB installation from Questie also works.
2. Download the installable ZIP from [GitHub Releases](https://github.com/damoninc/wow-forever-questchain/releases) and extract it into your Forever client's `Interface/AddOns` directory. The ZIP contains the `ForeverQuestChain` folder. For a source checkout, copy that folder from this repository instead.
3. Enable **QuestChain** in the AddOns list. Click the book icon by the minimap or run `/questchain` in chat. Drag the icon to move it. If the new addon is absent from the AddOns list, restart the client.

The journal has five main tabs: **Search**, **Zones**, **Dungeons**, **Class Quests**, and **Active Chains**. Search by title or quest ID, or choose a location card to explore its **Quests** and **Rewards** sections. Location cards sort by level and offer name and level filters. **Current Zone** opens the quests for your current location.

Location cards use Blizzard's journal borders and title styling. Classic dungeons use the client's journal thumbnails, and zones use the client's map tiles. Locations without available artwork use parchment. Hover a card to see its chain and standalone quest counts.

Opening a quest drills into its timeline within the current tab. **Back** returns to the list or reward sources you came from. Linear steps run down the center of the timeline. Sibling branches sit side by side and reconnect at their shared next step. Hold **Shift** while scrolling to pan wide branches.

Right-click a quest in WoW's Quest Log and choose **Open in QuestChain** to jump to its step. The quest details page also has an **Open in QuestChain** button beside **Back**.

**Active Chains** groups known chains with quests in your log into collapsible dungeon and zone sections. Dungeon chains include preparation steps picked up elsewhere. Other chains appear under the pickup zones of their active steps. A chain appears once per matching section, and the tab's total counts distinct chains. Sections start expanded and remember their state while the addon is loaded. Selecting a chain opens a step ready to turn in when one is available. Use **Back** to return to the list.

Use the breadcrumbs above the timeline to return to the location cards or reopen the current zone, dungeon, or class list. The trail keeps the category you opened the chain from. When opening from the quest log, it uses the selected quest's known category. A verified dungeon assignment takes priority over the pickup zone. **Earlier quests** jumps to a preceding step in the current chain.

Zone results follow pickup locations, so a chain can appear in several zones with different steps under each. **Class Quests** opens your class's quests and includes a picker for other classes. The Zones, Dungeons, and Class Quests tabs remember their selections, filters, page, and list position independently while the addon is loaded.

The **Quest log** column in Search and the **Status** column in location quests show your current character's progress.

Search results and timeline cards show how many party members currently have that quest in their log. Hover the row or card for names. Party members can appear without installing QuestChain.

In a location's **Quests** section, use **Hide completed** or **Show completed** to narrow the list. **Show all** clears the filter. These controls also work in class browsing.

In category browsing, chain rows come first, followed by standalone quests. Each group sorts by level, lowest first, with unknown levels at the end. A chain uses its lowest known quest level and shows progress for the steps in that category. Click it to open the timeline at a relevant step. A partly finished chain can appear under **Show completed**, which opens it at a completed step. Search results sort by quest level.

Zone and dungeon pickers also sort by level and show a range when available. Ranges come from the game map when it supplies them, or from the category's quest levels. Dungeon chains include linked steps outside the instance when opened.

Select **Rewards** inside a zone or dungeon to browse its quest reward items. Search by item name or ID and hover an item for its tooltip. Choose a source quest to open its chain, then use **Back** to resume browsing. Each location remembers its item search, selected reward, and scroll positions. The list uses item-to-quest links available in QuestieDB.

In **Quest Details**, select **Show on map** under a pickup or turn-in location with known coordinates. The action opens the zone map and adds a TomTom waypoint if TomTom is enabled. Otherwise QuestChain marks the location until you close the world map. Use `/questchain` to return to the selected quest.

Select a step to see its objectives, prerequisites, pickup and turn-in information, and rewards. Guaranteed items and pick-one rewards appear separately. Hover an item for its tooltip. **Unavailable** means the client could not supply a confirmed value for that field.

## Test in Forever

- Open **Dungeons**, select **Scarlet Monastery**, switch between **Quests** and **Rewards**, open a source quest, and use **Back**. Switch to **Zones** and back to check that each tab keeps its place.
- Search a repeated title such as **The Defias Brotherhood**, open a result, and click a different timeline step.
- Look up a branch or join such as **Big Game Hunter** (`208`) and a Forever-original quest. Follow the connectors and check the requirements.
- Compare the panel with Blizzard's quest offer for a quest that awards coin or choice items. Switch quests quickly and verify that the reward details follow your selection.
- Accept or turn in a quest in the displayed chain and check that its status changes.

## Develop locally

Run the development commands from the repository root with Lua 5.1, LuaRocks, and Python 3. On Windows, the commands below also work in WSL. LuaRocks needs Lua 5.1 headers and a C compiler to build Luacheck’s LuaFileSystem dependency when a binary rock is unavailable.

```sh
luarocks --lua-version=5.1 --tree=.rocks make --only-deps
.rocks/bin/luacheck ForeverQuestChain
python3 tools/check-lua.py
python3 tests/runtime.py
python3 tests/release.py
```

Use `--lua /path/to/lua` to select a specific Lua 5.1 interpreter for `tools/check-lua.py`. On native Windows, use `python` and run the Luacheck wrapper from `..rocksin`.

The rockspec pins Luacheck for development. The game loads Lua and XML in TOC order, and players install QuestieDB as an addon. See [AGENTS.md](AGENTS.md) for the XML template standard and manual playtest workflow.

## Publishing

**Every push or merge to `main` automatically publishes a stable Release to GitHub and CurseForge after the checks pass.** Pull requests run the checks without publishing. Merge changes when they are ready for players.

Changes reach protected `main` through pull requests. The required GitHub Actions `Tests` check must pass against an up-to-date base, and review conversations must be resolved. Force pushes and branch deletion are blocked, including for admins. The intended settings are recorded in `.github/branch-protection.json`. `.github/workflows/ci.yml` runs the Lua, version, and packaging checks on PRs and is reused by the main deployment workflow.

The **Deploy GA** workflow reuses CI, assigns the next patch version (for example `v1.0.0` to `v1.0.1`), and tags the merged commit itself. There is no release button, version-bump commit, or manual TOC edit. Releases are queued rather than cancelled when more merges arrive.

The Git tag is the version source. `## Version: @project-version@` in the source TOC is filled by the pinned BigWigs packager. One publishing invocation builds one installable ZIP and uploads that same file to GitHub and CurseForge as Release. GitHub also receives the Forever `release.json` manifest used by addon managers.

Each release includes `curseforge-upload.json`: the accepted CurseForge file ID, source commit, archive name, stable release type, and ZIP checksum. CI downloads the GitHub ZIP and verifies it against this checksum. The deployment summary links the GitHub release and identifies the CurseForge file.

The CurseForge project ID is `1792071`, recorded in the TOC as `X-Curse-Project-ID`. The repository needs the `CF_API_TOKEN` Actions secret. GitHub uses its built-in token; no extra access token is required. QuestieDB is a required CurseForge dependency and TomTom is optional. GitHub/manual users must install QuestieDB separately.

A completed deployment rerun verifies its existing release. A failed or ambiguous CurseForge upload stops without automatically repeating the POST; inspect the retained deployment files before retrying so an accepted file is not uploaded twice. Released tags remain immutable. A new merge gets a new version.

CurseForge can moderate and index files after accepting the upload. The project must be non-Experimental and its file tagged for Forever for app discovery. GitHub releases provide the package and metadata for WowUp; Hub indexing is managed externally.

## Editor IntelliSense

Open the repository root in VS Code with the [Lua extension](https://marketplace.visualstudio.com/items?itemName=sumneko.lua). From the repository root, run `pwsh -File ./tools/setup-intellisense.ps1`. If your game is installed elsewhere, pass the QuestieDB addon directory with `-QuestieDBPath`. Then reload the editor window.

Hover an API in the addon source for parameters and return types, or type `C_QuestLog.` for completions. LuaLS reads the [Forever client export](https://github.com/Atraeau/WoW-Addons/blob/1b8fa2898e15d20dfbffdcdaf6264df3d708f225/types/WowForeverAPI.lua), [shared FrameXML types](https://github.com/Ketho/vscode-wow-api/tree/0.22.3/Annotations/Core/Widget), and QuestieDB's shipped declarations. The Forever export is from build 70790. Some legacy signatures live in `types/wow-forever-globals.lua`.
