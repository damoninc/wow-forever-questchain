# Protected main and shared CI

**Goal:** Require passing PR tests before merging to main, while keeping automatic GA deployment after every merge.

- Move existing Lua, version and real packaging checks into `.github/workflows/ci.yml`, named `CI` with the stable required job name `Tests`.
- Run CI on PRs targeting main and reuse it from the main-only deployment workflow. Keep one publisher and the same tested source commit.
- Store the intended main protection in `.github/branch-protection.json` and apply it through the owner API after the new check has run.
- Require PRs, up-to-date passing GitHub Actions `Tests`, and resolved conversations. Enforce for admins and disallow force pushes/deletion.
- Do not require another person's approval for this owner-operated repository; the PR and test gate remain mandatory.
- Verify locally, review the workflow change independently, open a PR, observe its real `Tests` check, enable protection, merge normally, and verify automatic GA deployment.
