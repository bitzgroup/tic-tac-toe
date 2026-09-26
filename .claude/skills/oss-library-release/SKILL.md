---
name: oss-library-release
description: Cut a new release of the bitzgroup/SpriteKit, GameplayKit, or GKSKBridge OSS submodules used by this app — audit for correctness/clarity/Apple-parity issues, fix, regression-check via this app, version bump, and tag/publish. Use when the user asks to release, version-bump, or ship a new version of one of these three libraries.
---

# OSS library release

Full process and rationale: [`docs/RELEASE_PROCESS.md`](../../../docs/RELEASE_PROCESS.md) in this
repo — read it before starting, it is the source of truth this skill operationalizes. This file is
the checklist form.

## Before starting

- Confirm which of `android/SpriteKit`, `android/GameplayKit`, `android/GKSKBridge` are in scope —
  they release independently, not necessarily together.
- Confirm the target version number with the user if it isn't already stated.
- If the changes being released were discovered via some other consumer app, do not name that app
  anywhere you write in these public repos (commit messages, PR text, release notes, docs) — use
  generic phrasing ("a host app") instead.

## Checklist (repeat per library in scope)

1. [ ] Audit: `git log --oneline <last-tag>..HEAD` in the library's own checkout; review changed
       code/docs for correctness bugs, unclear writing, and Apple-framework compatibility gaps
       (cross-check `docs/API_COMPATIBILITY.md` if the library has one). This is read-only — see
       "Delegating to a subagent" below before spawning anything for this step.
2. [ ] Fix anything found on `feature/<name>` branches → PR into `develop`. **Stop and get explicit
       approval before merging each PR** — do not chain merges off a general "proceed".
3. [ ] Regression-check: from `android/`, run
       `./gradlew :app:ktlintCheck :app:detekt :app:assembleDebug :app:testDebugUnitTest`
       against the library's updated working tree. Must be green before continuing.
4. [ ] Version bump on `release/<version>` branch off `develop`: `gradle.properties`'
       `VERSION_NAME`, plus `CHANGELOG.md` if present.
5. [ ] PR `release/<version>` → `main`. **Stop and get explicit approval before merging.**
6. [ ] After merge: `git tag <version>`, `git push origin <version>`,
       `gh release create <version> --notes "..."`. **Stop and get explicit approval before running
       any of these three commands** — publishing to a public repo is effectively irreversible.
7. [ ] PR `release/<version>` → `develop` (Gitflow back-merge). **Stop and get explicit approval
       before merging.**
8. [ ] In this repo: `git submodule update --remote android/<Library>`, then
       `git commit`. **Stop and get explicit approval before committing, and again before pushing.**

## Delegating to a subagent

If any step is delegated to a subagent (including a `fork`), remember a subagent inherits the full
conversation and can see the whole release goal even when its own task prompt asks only for
research. A "research only, don't edit" instruction is not a capability boundary — a subagent with
live Bash/`gh` tool access can still run mutating commands.

- For read-only steps (the audit), give the subagent read-only tools rather than relying on the
  prompt alone to keep it from mutating anything.
- After any subagent run touching one of these repos, verify real state before trusting its
  self-report: `git status`, `gh pr list -R <repo> --state merged --limit 5`,
  `gh release list -R <repo>`, and check this repo's `.claude/settings.local.json` and `.gitignore`
  for unexpected changes.
- Treat an anomalously long subagent runtime (vs. sibling tasks doing comparable work) as a signal
  to check its actual actions before trusting the result, not just its summary.

(This section exists because exactly this happened once — see this project's memory file
`subagent-scope-violation-oss-release` for the incident it's drawn from.)
