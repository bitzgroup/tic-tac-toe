# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Intent

This repo is a **sample app, not a library**: Tic-Tac-Toe implemented twice, once on iOS with
Apple's official SpriteKit + GameplayKit, once on Android with
[bitzgroup/SpriteKit](https://github.com/bitzgroup/SpriteKit),
[bitzgroup/GameplayKit](https://github.com/bitzgroup/GameplayKit), and
[bitzgroup/GKSKBridge](https://github.com/bitzgroup/GKSKBridge) (Kotlin ports of Apple's
frameworks plus the bridging surface between them, embedded here as git submodules). The goal is to
demonstrate, side by side, that the OSS Android ports behave the same as the official Apple
frameworks they mirror. See
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full rationale and repository layout, and
[`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) for the one game spec both apps implement.

## Project status

Documentation and implementation plan only — no app code yet. See
[`docs/ROADMAP.md`](docs/ROADMAP.md) for the phased plan and progress checklist; update this
section (and that file's checkboxes) as phases land.

## Project structure

```text
tic-tac-toe/
├── docs/          # GAME_DESIGN.md, ARCHITECTURE.md, ROADMAP.md
├── ios/           # planned: Xcode project, Swift, Apple's SpriteKit + GameplayKit
└── android/       # planned: Gradle project, Kotlin, SpriteKit/GameplayKit/GKSKBridge as git submodules
```

- `docs/GAME_DESIGN.md` — rules, GameplayKit AI/state-machine design, SpriteKit presentation spec,
  and the parity checklist used to sign off that the two apps match. This is the single source of
  truth both platforms implement against — keep both apps in sync with it, not with each other
  directly.
- `docs/ARCHITECTURE.md` — repository layout, the exact Swift/Kotlin file layout suggested for each
  app, and how the Android app wires `SpriteKit`/`GameplayKit`/`GKSKBridge` in as git submodules.
- `docs/ROADMAP.md` — phased implementation plan; each phase lands on both platforms before the
  next phase starts, so the two apps never drift far apart in capability.

## Commands

Neither app exists yet (Phase 0 of `docs/ROADMAP.md`). Once scaffolded:

- iOS (from `ios/`): build/test via Xcode, or `xcodebuild build`/`xcodebuild test` from the CLI.
- Android (from `android/`): `./gradlew assemble`, `./gradlew testDebugUnitTest` — same Gradle
  commands as the `SpriteKit`/`GameplayKit`/`GKSKBridge` submodules themselves, since `:app` shares
  their `minSdk`/`compileSdk`/Kotlin baseline.

Update this section with the real commands once each project is scaffolded.

## Git Branching Workflow

This repo follows a [Gitflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)-style
branching model, the same convention `bitzgroup/SpriteKit` and `bitzgroup/GameplayKit` use.

| Branch | Branches from | Merges into | Naming |
|---|---|---|---|
| `main` | — | — | Always releasable. Direct pushes are blocked (branch protection); merge only from `release/*` or `hotfix/*`. |
| `develop` | `main` | — | Integration branch for work heading to the next release. |
| `feature/<name>` | `develop` | `develop` | e.g. `feature/phase-0-scaffolding`, `feature/phase-1-game-model`. |
| `release/<version>` | `develop` | `main` **and** `develop` | e.g. `release/0.1.0`. Release-prep fixes only, no new features. |
| `hotfix/<name>` | `main` | `main` **and** `develop` | Urgent fixes to a released `main`. |

- Every merge goes through a PR — `main`/`develop` branch protection is live (no direct pushes, no
  force-push/deletion), matching `bitzgroup/SpriteKit`/`GameplayKit`'s settings except their
  required `build` CI status check, which isn't set here yet since this repo has no CI workflow
  until an app is scaffolded (see `docs/ROADMAP.md` Phase 0) — add it as a required check on both
  branches once that CI exists.
- `release/*`/`hotfix/*` don't exist yet: the first release is cut once Phases 0–4 of
  `docs/ROADMAP.md` are complete. Until then, all work happens on `feature/*` branches merged into
  `develop` — `main` isn't touched again until that first release.

## Working in this repo

- **Documentation language:** all docs (README, code comments, ROADMAP, etc.) must be written in
  **English** — this is a public OSS sample, matching the convention of the `SpriteKit` and
  `GameplayKit` sibling repos it demonstrates.
- **App UI language is separate from documentation language:** both apps' user-facing strings are
  localized, base language English (`en`) plus a full Japanese (`ja`) translation — see
  `docs/GAME_DESIGN.md`'s "Localization" section for the key/string table and
  `docs/ARCHITECTURE.md` for the file mechanism on each platform. This applies to in-app labels
  only; it does not relax the English-only rule above for docs/comments/commit messages.
- **Documentation location:** project docs beyond the root `README.md` live under `docs/`.
- **Design changes go in `docs/GAME_DESIGN.md` first.** Since the iOS and Android apps share no
  code, anything that must stay identical between them (rules, AI behavior, layout, animation
  timing) needs to be a spec change there before it's implemented on either platform — otherwise
  the two apps silently drift and the parity story this repo exists to tell breaks.
- **`android/SpriteKit`, `android/GameplayKit`, and `android/GKSKBridge` are git submodules**, not
  vendored copies — see `docs/ARCHITECTURE.md`'s "Working with the submodules" section for
  clone/update commands. Don't hand-edit files inside them from this repo; changes belong upstream
  in their own repositories. `GKSKBridge` is still pre-scaffolding upstream as of this writing (see
  its own `CLAUDE.md`) — its module name/layout isn't final, so treat anything about it here as
  provisional until that repo settles it.
- **Git operations:** do not run `git commit` or `git push` unless explicitly requested by the user
  for that specific change.
