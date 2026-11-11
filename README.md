# QuestChain for WoW: Forever

QuestChain is an in-game quest-chain reference for **WoW: Forever**. Look up a quest before accepting it to see where the chain starts, what unlocks the next step, and what the chain offers. Follow your character's progress and inspect XP, coin, and item rewards without leaving the game.

## Install

1. Install or enable the Forever version of [QuestieDB](https://github.com/Questie/QuestieDB/releases). A compatible QuestieDB installation from Questie also works.
2. Download the installable ZIP from [GitHub Releases](https://github.com/damoninc/wow-forever-questchain/releases) and extract it into your Forever client's `Interface/AddOns` directory. The ZIP contains the `ForeverQuestChain` folder. For a source checkout, copy that folder from this repository instead.
3. Enable **QuestChain** in the AddOns list and run `/questchain` in chat. Use `/reload` if you added it during a session. If the new addon is absent from the AddOns list, restart the client.

Search by title or quest ID. Linear steps run down the center of the timeline. Sibling branches sit side by side and reconnect at their shared next step. Hold **Shift** while scrolling to pan wide branches.

Right-click a quest in WoW's Quest Log and choose **Open in QuestChain** to jump to its step. The quest details page also has an **Open in QuestChain** button beside **Back**.

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

Versions follow `major.minor.patch`: increment patch for fixes, minor for features, and major for significant breaking changes. The source TOC keeps the numeric version. A tag must match it exactly, for example `## Version: 0.1.0` and `v0.1.0`. Optional betas use a matching version such as `0.2.0-beta.1` / `v0.2.0-beta.1`.

The **Package QuestChain** workflow runs Lua 5.1 fixtures and real packaging checks for pull requests, pushes to `main`, and manual runs. Branch builds remain GitHub Actions artifacts; they are not uploaded to CurseForge. BigWigs stamps the packaged TOC and ZIP with the Git-derived build version. Development versions include the source commit once they are past a release tag.

To publish, open **Actions → Release QuestChain → Run workflow** on `main`:

1. Choose `patch` for fixes, `minor` for features, or `exact` to enter a specific version without the `v` prefix. Use `exact` for major releases and beta progression or promotion.
2. Check **Preview** first if you want to inspect the candidate version and installable ZIP. Preview runs do not push commits, create remote tags, or publish files.
3. For a release, leave Preview unchecked. The action updates only the TOC version, creates a local version commit and tag, runs the Lua and packaging checks, then pushes the commit and tag together. It invokes **Package QuestChain** directly to test and publish that exact tag.

Playtest affected runtime changes in Forever before releasing. The action requires the current `main` commit and respects branch protection. If `main` advances during verification, its atomic push fails without creating a partial release; start a new run. A failed publication after the push leaves the version commit and tag in place; follow the recovery instructions below.

The workflow uses GitHub's built-in token. Its automated tag push does not start another push workflow, so the release action explicitly calls our packaging workflow. No additional personal access token is required. BigWigs remains the pinned packaging tool running inside our GitHub runner; our repository owns the version bump, tests, package configuration, and publication controls.

Use meaningful Conventional Commit prefixes such as `fix:`, `feat:`, and `chore:` for release notes. The action uses the bump you select; it does not infer versions from commit messages.

Manual releases still work: update and commit the TOC version yourself, then push its matching annotated tag, for example `git tag -a v0.1.1 -m "QuestChain 0.1.1"` followed by `git push origin v0.1.1`.

Tagged pushes publish the same packaged build to CurseForge and a GitHub Release. Stable tags use CurseForge's **Release** channel; `-beta.N` tags use **Beta** and a GitHub prerelease. GitHub releases contain an installable ZIP, changelog, and BigWigs `release.json` with the Forever flavor for addon managers. Keep released tags immutable; publish a new version for changes.

The CurseForge project ID is `1792071`, recorded in the TOC as `X-Curse-Project-ID`. Store the upload token as the GitHub Actions repository secret `CF_API_TOKEN`. The old `CF_PROJECT_ID` repository variable is no longer used. QuestieDB is a required CurseForge dependency; TomTom is optional. GitHub/manual users must install QuestieDB separately.

Publishing reserves a draft GitHub Release before any platform upload and refuses to run if that tag already has a release or reservation. The pinned BigWigs publisher is prepared locally to disable both automatic CurseForge upload retry layers; packaging and metadata generation remain upstream. A failed or timed-out POST stops publication for inspection. An interrupted run can leave that draft, or an uploaded CurseForge file awaiting approval. **Do not blindly rerun or delete the reservation.** Inspect the failed job and CurseForge files first. If CurseForge accepted nothing and no run is active, remove only the incomplete GitHub draft (preserve the tag), then rerun the failed publication job. If CurseForge accepted the file, finish the GitHub release using the retained build artifact and manifest format rather than uploading to CurseForge again.

Project approval and file approval are separate. For app discovery, verify an approved Release/Beta file is tagged for Forever and the project is not Experimental. After the first GitHub release, verify the repository is listed in the [WowUp Hub](https://wowup.io/guide/wowup/hub); GitHub releases alone do not guarantee search indexing.

## Editor IntelliSense

Open the repository root in VS Code with the [Lua extension](https://marketplace.visualstudio.com/items?itemName=sumneko.lua). From the repository root, run `pwsh -File ./tools/setup-intellisense.ps1`. If your game is installed elsewhere, pass the QuestieDB addon directory with `-QuestieDBPath`. Then reload the editor window.

Hover an API in the addon source for parameters and return types, or type `C_QuestLog.` for completions. LuaLS reads the [Forever client export](https://github.com/Atraeau/WoW-Addons/blob/1b8fa2898e15d20dfbffdcdaf6264df3d708f225/types/WowForeverAPI.lua), [shared FrameXML types](https://github.com/Ketho/vscode-wow-api/tree/0.22.3/Annotations/Core/Widget), and QuestieDB's shipped declarations. The Forever export is from build 70790. Some legacy signatures live in `types/wow-forever-globals.lua`.
