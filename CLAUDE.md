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

Phase 0 (repository scaffolding), Phase 1 (GameplayKit game model: `TicTacToeBoard`/
`TicTacToeGameModel`/`TicTacToeMatch`, AI difficulty strategists, `GKStateMachine` turn flow),
Phase 2 (SpriteKit board rendering & input: `MenuScene`/`GameScene`, marks as `GKEntity` +
`GKSKNodeComponent`, touch handling, win-line pulse, `en`/`ja` localization), Phase 3 (platform app
shells presenting `MenuScene` at launch; both apps verified playable start-to-finish at all three
difficulties), Phase 4 (parity verification: Hard-mode move-for-move parity tests, entity-lifecycle
tests, and a full `en`/`ja` visual pass on an iOS Simulator and an Android Emulator), and Phase 5
(polish: win-particle burst via `SKEmitterNode`, tap/win sound effects, app icons on both
platforms), and Phase 6 (documentation & release — README screenshots, `v0.1.0` tagged and
released, alongside `0.1.0` releases of `bitzgroup/SpriteKit`/`GameplayKit`/`GKSKBridge`) are
complete on both platforms, both fully unit-tested (26 tests on iOS incl.
`GameScenePlaythroughTests`/`TicTacToeHardStrategistParityTests`/
`GKMonteCarloUnapplyCompatibilityTests`, 20 on Android) and visually/manually verified (simulator/
emulator screenshots, on-device playthroughs). Phase 7 (post-`v0.1.0` Apple-parity audit: a
systematic pass looking for every place the Android app had to diverge from the iOS app because a
bitzgroup library behaved or was shaped differently from Apple's — each treated as an OSS
compatibility bug and fixed upstream, then the Android app changed back to match iOS) is also
complete, and drove the `0.2.0` releases of all three bitzgroup libraries. Phase 8
(Apple-platforms parity probes: `apple-platforms/`'s `SpriteKitParity`/`GameplayKitParity`
schemes recording Apple's real behavior on iOS/tvOS) is complete too, and drove their `0.3.0`
releases; the probes then drove the libraries' P1 parity work, released as `bitzgroup/SpriteKit`/
`GameplayKit` `0.4.0`. See `docs/ROADMAP.md`
Phase 1 for a real OSS/Apple discrepancy the iOS-first implementation order caught, fixed upstream
in `bitzgroup/GameplayKit` itself; Phase 2 for two more (`bitzgroup/GKSKBridge`'s
`GKScene.entities`, `bitzgroup/SpriteKit`'s missing `SKScene.view`/`SKViewState` transition
overload); Phase 4 for a real Android-only bug the parity pass itself caught and fixed (the
`score_row` string's double spaces being collapsed to single spaces by Android's resource
compiler); Phase 5 for another Android-only bug on-device audio verification caught (the
commonly-cited `file:///android_asset/…` `MediaPlayer` trick failing silently at runtime despite a
clean build — originally worked around by copying sound assets to `Context.getCacheDir()`; since
fixed upstream in `bitzgroup/SpriteKit` by Phase 7's audit, so both apps now pass the same plain
file name); and Phase 7 itself for the `GKMonteCarloStrategist`/`GKMinmaxStrategist` distinction
(only `GKMinmaxStrategist` requires `unapplyGameModelUpdate` to be a true inverse — `bitzgroup/
GameplayKit` had briefly unified the two, reverted after `GKMonteCarloUnapplyCompatibilityTests`
checked the real on-device framework) plus several `bitzgroup/SpriteKit` gaps (touch-callback
shape, sprite/particle texture-derived sizing, `zPosition` accumulation, `.aspectFit`/`.aspectFill`
anchor centering). See [`docs/ROADMAP.md`](docs/ROADMAP.md) for the phased plan and progress
checklist; update this section (and that file's checkboxes) as phases land.

## Project structure

```text
tic-tac-toe/
├── docs/          # GAME_DESIGN.md, ARCHITECTURE.md, ROADMAP.md
├── apple-platforms/  # Xcode project (XcodeGen-generated), Swift, Apple's SpriteKit + GameplayKit:
│                     # the iOS game app plus iOS/tvOS SpriteKit/GameplayKit parity probes
└── android/       # Gradle project, Kotlin, SpriteKit/GameplayKit/GKSKBridge as git submodules
```

- `docs/GAME_DESIGN.md` — rules, GameplayKit AI/state-machine design, SpriteKit presentation spec,
  and the parity checklist used to sign off that the two apps match. This is the single source of
  truth both platforms implement against — keep both apps in sync with it, not with each other
  directly.
- `docs/ARCHITECTURE.md` — repository layout, the exact Swift/Kotlin file layout suggested for each
  app, and how the Android app wires `SpriteKit`/`GameplayKit`/`GKSKBridge` in as git submodules.
- `docs/ROADMAP.md` — phased implementation plan; each phase lands on both platforms before the
  next phase starts, so the two apps never drift far apart in capability.
- `docs/RELEASE_PROCESS.md` — the step-by-step process for cutting a new version of the
  `SpriteKit`/`GameplayKit`/`GKSKBridge` OSS submodules (audit → fix → regression-check via this
  app → version bump → tag/release), including the per-action git approval and subagent-safety
  rules that process runs under.

## Commands

- **iOS / Apple platforms** (from `apple-platforms/`):
  - Regenerate the Xcode project after adding/removing files: `xcodegen generate` (needs
    [XcodeGen](https://github.com/yonaskolb/XcodeGen); `project.yml` is the source of truth, the
    generated `.xcodeproj` is committed too — see `docs/ARCHITECTURE.md`).
  - Build: `xcodebuild -project TicTacToe.xcodeproj -scheme TicTacToe -destination 'platform=iOS Simulator,name=<simulator>' build`
  - Run all tests: `xcodebuild test -project TicTacToe.xcodeproj -scheme TicTacToe -destination 'platform=iOS Simulator,name=<simulator>'`
  - Run a single test: add `-only-testing:TicTacToeTests/TicTacToeBoardTests/testSomeCase` to the
    command above.
  - Or open `TicTacToe.xcodeproj` in Xcode directly (build/run/test from there).
  - SpriteKit parity probes (records of Apple's real SpriteKit behavior that `bitzgroup/SpriteKit`
    mirrors — see `docs/ARCHITECTURE.md`'s "SpriteKit parity probes"): `xcodebuild test -project
    TicTacToe.xcodeproj -scheme SpriteKitParity -destination 'platform=tvOS Simulator,name=<Apple
    TV simulator>'` (and again with an iOS Simulator destination). Add a probe here before
    implementing an Apple behavior in `bitzgroup/SpriteKit`.
  - GameplayKit parity probes (the same for `bitzgroup/GameplayKit`, plus the GameplayKit ↔
    SpriteKit glue `bitzgroup/GKSKBridge` mirrors): the same command with `-scheme
    GameplayKitParity`.
  - **CI (`.github/workflows/ci.yml`) only builds the iOS app and the parity probes — it runs
    neither `TicTacToeTests` nor the parity probes.** (The CI job is still named `ios`: it's a
    required status check in branch protection.) Unlike Android, an iOS regression won't be caught by CI; run the test
    command above (or Xcode's Test navigator) yourself before considering an iOS change done.
- **Android** (from `android/`): `./gradlew :app:assembleDebug`, `./gradlew :app:testDebugUnitTest`,
  `./gradlew :app:ktlintCheck`, `./gradlew :app:detekt` — scoped to `:app` for the same reason
  `bitzgroup/GKSKBridge` scopes its own commands to `:gkskbridge` (see its `CLAUDE.md`): an
  unscoped task also runs against the included `SpriteKit`/`GameplayKit`/`GKSKBridge` submodule
  projects, whose build scripts resolve `$rootDir`-relative paths (their own
  `config/detekt/detekt.yml` overrides) against *this* repo's root once included here, not their
  own.
  - Run a single test: `./gradlew :app:testDebugUnitTest --tests "jp.co.bitz.tictactoe.game.TicTacToeGameModelTest"`.
  - All four checks above (`ktlintCheck`, `detekt`, `assembleDebug`, `testDebugUnitTest`) are what
    CI runs and what `docs/RELEASE_PROCESS.md` calls the regression check for the OSS submodules.

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
  force-push/deletion), matching `bitzgroup/SpriteKit`/`GameplayKit`'s settings including their
  required CI status checks (`.github/workflows/ci.yml`'s `ios`/`android` jobs).
- `release/*`/`hotfix/*` are short-lived: this repo's own `v0.1.0` was cut this way once Phases
  0–6 of `docs/ROADMAP.md` were complete. Day-to-day work (including Phase 7 and later) happens on
  `feature/*` branches merged into `develop`; `main` is only touched again for the next
  `release/*`/`hotfix/*`.

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
- **Never name a private/unreleased consumer app.** This repo and the three OSS submodules it
  demonstrates are all public; some upstream fixes originate from other, unrelated apps built
  against those submodules, and those apps may be private. Never reference such an app by name
  anywhere in this repo or the submodule repos — commit messages, PR text, comments, or docs. Use
  generic phrasing instead ("a host app", "a consumer app"). See `docs/RELEASE_PROCESS.md`.
- **Design changes go in `docs/GAME_DESIGN.md` first.** Since the iOS and Android apps share no
  code, anything that must stay identical between them (rules, AI behavior, layout, animation
  timing) needs to be a spec change there before it's implemented on either platform — otherwise
  the two apps silently drift and the parity story this repo exists to tell breaks.
- **`android/SpriteKit`, `android/GameplayKit`, and `android/GKSKBridge` are git submodules**, not
  vendored copies — see `docs/ARCHITECTURE.md`'s "Working with the submodules" section for
  clone/update commands. Don't hand-edit files inside them from this repo; changes belong upstream
  in their own repositories. **All three currently track their `develop` branch** (not a pinned
  release tag) for the duration of active co-development across the four repos — see
  `docs/ARCHITECTURE.md`'s "Working with the submodules" section for why and how to switch back to
  tag-pinning later.
- **`.gitignore`** (root) covers macOS `.DS_Store`; `apple-platforms/.gitignore` and `android/.gitignore` cover
  each platform's own build artifacts — same split as the `SpriteKit`/`GameplayKit`/`GKSKBridge`
  sibling repos.
- **Git operations require an explicit request, every time.** This covers the whole workflow —
  `git commit`, `git push`, opening a PR (`gh pr create`), and merging one (`gh pr merge`) — not
  just the two literal commands named. A general "proceed" on a feature/task is not standing
  authorization for the git steps that follow it: implement, edit, build, and verify freely, but
  stop before each commit/push/PR-create/PR-merge and wait for that specific go-ahead, even
  mid-task and even if the user approved a git action earlier in the same conversation. This
  applies identically inside the `android/SpriteKit`/`GameplayKit`/`GKSKBridge` submodule
  checkouts.
