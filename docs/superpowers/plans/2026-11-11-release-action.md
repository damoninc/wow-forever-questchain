# Automated Release Preparation Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for inline execution of the approved release-action request.

**Goal:** One explicit action bumps the TOC, tests the candidate, commits and tags it, then invokes the existing publisher.

**Architecture:** Keep release/version decisions in this repository. Reuse the existing packaging workflow directly after the built-in GitHub token pushes the version commit and tag together. Keep the existing pinned BigWigs tool and packaging logic, as clarified by the user.

**Tech Stack:** GitHub Actions, Python standard library, Bash, Lua 5.1, pinned BigWigs v2.7.0.

**Spec:** User approved an explicit patch/minor/exact release action with an automatic source TOC bump, and requested review and ownership of packaging logic. Prior authorization to commit to main and push persists for these pipeline changes.

## Constraints

- Preserve pre-existing uncommitted UI work; stage only this task's changes.
- Keep ForeverQuestChain root folder, interface 16001, QuestieDB required, and TomTom optional.
- Never publish on ordinary main/PR CI builds or preview release runs.
- Test the local version commit/tag before publishing either ref; push both refs atomically and respect branch protection.
- Use workflow_call explicitly because GITHUB_TOKEN-created tag pushes do not trigger the tag workflow.
- Refuse stale main snapshots, existing versions/tags, and version downgrades.
- Keep the single-attempt CurseForge uploader and interrupted-upload reservation.
- No new public addon version is requested in this task; verify the action using preview mode.

## Task 1: Version preparation

- [x] Write failing tests for patch/minor/exact versions, beta ordering, invalid versions, and TOC-only edits preserving line endings.
- [x] Implement `tools/bump-version.py` with no third-party Python dependencies.
- [x] Add a manual Release QuestChain workflow: prepare a local version commit/tag, run fixtures and packaging, then atomically push and call the publisher; preview mode retains artifacts without pushing/publishing.

## Task 2: Reuse packaging

- [x] Add workflow_call to Package QuestChain, checking out and testing the requested tag consistently in both jobs.
- [x] Document the release button, preview behavior, unchanged BigWigs dependency, and recovery flow.

## Task 3: Verify and ship

- [x] Run all release/version/packaging tests, five Lua suites, syntax checks, and actionlint against the intended commit.
- [x] Obtain independent read-only review and resolve material findings.
- [ ] Commit only this task's changes to main, push, and inspect CI.
- [ ] Run the release action in preview mode; verify its ZIP and unchanged main/version/tag state.

## Execution notes

- The user clarified that using BigWigs is good. Packaging-tool changes were dropped; this task only adds release preparation and the explicit call into the existing tested packaging workflow.
- Independent review found ambiguous bare-tag checkouts and a beta fixture that failed when source was already the documented beta version. Checkouts now use refs/tags explicitly. The beta fixture uses an allowed empty fixture commit; its beta-source reproduction failed before the change and passed afterward.
- Local verification passed: four version tests, seven real packaging tests, five Lua fixture suites, Bash/Lua syntax, and actionlint. The new packaging case verifies that a bumped source commit and local tag produce the new package version while the committed TOC remains numeric.
