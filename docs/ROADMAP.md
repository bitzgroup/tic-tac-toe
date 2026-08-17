# Roadmap

Phased implementation plan for the iOS and Android Tic-Tac-Toe apps described in
[`docs/GAME_DESIGN.md`](GAME_DESIGN.md) and [`docs/ARCHITECTURE.md`](ARCHITECTURE.md). Each phase
is implemented on **both platforms before moving to the next phase**, so the two apps never drift
far apart in capability — that running-side-by-side comparison is the entire point of this repo.

Checklist items are marked `[ ]` until done; update this file as work lands, the same convention
`bitzgroup/SpriteKit` and `bitzgroup/GameplayKit` use in their own `docs/ROADMAP.md`.

## Phase 0 — Repository scaffolding

- [x] Root docs: `README.md`, `CLAUDE.md`, `docs/GAME_DESIGN.md`, `docs/ARCHITECTURE.md`, this file
- [x] `main`/`develop` branch protection (PR required, no direct pushes, no force-push/deletion) —
      matching `bitzgroup/SpriteKit`/`GameplayKit`'s settings; required CI status checks added once
      `.github/workflows/ci.yml` existed (see below)
- [x] `ios/` — Xcode project (project root, no extra nesting — mirrors `android/` being the Gradle
      root directly) generated via [XcodeGen](https://github.com/yonaskolb/XcodeGen) from
      `project.yml`, iOS 15+ deployment target, SwiftUI `App` presenting a blank `SKScene` via
      `SpriteView`, no game logic yet
- [x] `android/` — Gradle project skeleton; `SpriteKit`, `GameplayKit`, and `GKSKBridge` added as
      git submodules (currently tracking each repo's `develop` branch — see
      `docs/ARCHITECTURE.md`'s "Working with the submodules") and wired into
      `settings.gradle.kts`/`:app`'s `build.gradle.kts` per `docs/ARCHITECTURE.md`; `:app` presents
      a blank `spritekit-compose` `SKView`, no game logic yet
- [x] Both apps build and launch to a blank screen (`xcodebuild build` / `./gradlew assemble`,
      confirmed by installing and launching on a simulator/emulator) — see the note below on a
      `bitzgroup/SpriteKit` fix this surfaced
- [x] `bitzgroup/SpriteKit`'s `v0.1.0` had a real bug blocking `:spritekit-compose` and
      `bitzgroup/GKSKBridge`'s `:gkskbridge` from ever being embedded together (each required a
      different, incompatible Gradle project path for the shared `:spritekit` module — see
      [PR #24](https://github.com/bitzgroup/SpriteKit/pull/24) for the full explanation): fixed
      upstream, merged to `develop` then `main`, and republished as `v0.1.0` (replacing the
      original tag — nothing had consumed it yet, per the repo owner's direction).
      `android/SpriteKit` now tracks `develop`, which already includes this fix.
- [x] CI workflow (`.github/workflows/ci.yml`, `ios`/`android` jobs) for each app, then add both
      as **required** status checks on `main`/`develop` branch protection — closing the one gap
      noted above, bringing this repo's protection settings to full parity with
      `bitzgroup/SpriteKit`/`GameplayKit`. Along the way, fixed `.gitmodules` to use `https://`
      submodule URLs instead of `git@github.com:` — CI runners have no SSH key configured, so
      `actions/checkout`'s `submodules: recursive` would otherwise fail to clone them (public
      repos clone anonymously fine over HTTPS, so this has no functional downside).

## Phase 1 — Game model (GameplayKit)

Implemented independently in Swift (iOS, against Apple's `GameplayKit.framework`) and Kotlin
(Android, against `jp.co.bitz.gameplaykit`) from the same spec — see `docs/GAME_DESIGN.md`'s
"GameplayKit layer" section for the exact type/method shapes both must match.

- [ ] `TicTacToeBoard`: pure rules, no GameplayKit dependency — 9-cell state, move legality/
      application, win/loss/draw detection (all 8 lines), matching the FourInARow-precedent split
      in `docs/GAME_DESIGN.md`'s "Game model" section
- [ ] Unit tests directly against `TicTacToeBoard`: win detection (all 8 lines), loss detection,
      draw detection, legal-move generation at various board states — on both platforms, no
      GameplayKit fixture needed
- [ ] `TicTacToePlayer` (`GKGameModelPlayer`), `TicTacToeMove` (`GKGameModelUpdate`)
- [ ] `TicTacToeGameModel` (`GKGameModel`): wraps `TicTacToeBoard`, adds `copy()`/
      `setGameModel(_:)`, `gameModelUpdates(for:)` (ascending cell-index order — see the tie-break
      note in `docs/GAME_DESIGN.md`), `apply(_:)`, `score(for:)`, `isWin(for:)`, `isLoss(for:)`
- [ ] Unit test: `TicTacToeGameModel.copy()` independence (mutating the copy never affects the
      original) — on both platforms
- [ ] AI difficulty wiring: Easy (`GKRandomDistribution`), Normal (`GKMonteCarloStrategist`,
      `budget = 200`), Hard (`GKMinmaxStrategist`, `maxLookAheadDepth = 9`)
- [ ] Unit test: Hard AI never loses, across a representative set of opening/mid-game board states
      — on both platforms
- [ ] `GKStateMachine`/`GKState` turn flow: `TurnBeginState`, `HumanTurnState`, `AITurnState`,
      `TurnEndState`, `GameOverState`, with `isValidNextState(_:)` gating

## Phase 2 — Board rendering & input (SpriteKit + GKSKBridge)

Implemented independently against Apple's `SpriteKit.framework`/`GameplayKit.framework` (iOS) and
`jp.co.bitz.spritekit`/`jp.co.bitz.spritekit.compose`/`jp.co.bitz.gkskbridge` (Android) from
`docs/GAME_DESIGN.md`'s "Presentation" and "Marks as entities" sections.

- [ ] `GameScene`: 3×3 grid (`SKShapeNode` strokes), 9 tappable per-cell `SKShapeNode`s
- [ ] `GameScene` owns a `GKScene` (`rootNode` = itself); `TicTacToeMarkEntity` (`GKEntity`) +
      `TicTacToeMarkComponent` (`GKComponent`) + `GKSKNodeComponent` per placed mark, appended to
      `gkScene.entities` — see `docs/GAME_DESIGN.md`'s "Marks as entities" section
- [ ] `X`/`O` marks as stroked `SKShapeNode` paths (not label glyphs — see the rationale in
      `docs/GAME_DESIGN.md`), owned by their entity's `GKSKNodeComponent`, placement pop-in
      `SKAction`
- [ ] Status `SKLabelNode` (turn / thinking / result) and score row (`X` / `O` / `Draws`,
      in-memory only)
- [ ] Win-line pulse animation on the three winning cells
- [ ] `MenuScene`: difficulty picker, coin toss, `SKTransition.crossFade` into `GameScene`
- [ ] New Game: re-present a fresh `GameScene` via `SKTransition.crossFade`
- [ ] Wire `HumanTurnState`'s tap handling and `AITurnState`'s "thinking" delay (Phase 1) into the
      scene
- [ ] Localization: `en` base + `ja` translation for every key in `docs/GAME_DESIGN.md`'s
      Localization table (iOS: `Localizable.xcstrings`; Android: `values/strings.xml` +
      `values-ja/strings.xml`) — no label hardcoded into a scene

## Phase 3 — Platform app shells

- [ ] iOS: `TicTacToeApp.swift` presents `MenuScene` at launch inside an `SKView`/`SpriteView`
- [ ] Android: `MainActivity.kt` presents `MenuScene` at launch inside `spritekit-compose`'s
      `SKView`
- [ ] Both apps are playable start-to-finish end to end (menu → game → win/loss/draw → new game)
      at all three difficulties

## Phase 4 — Parity verification

- [ ] Walk the full checklist in `docs/GAME_DESIGN.md`'s "Parity checklist" section against both
      apps, same device pixel density class on each side
- [ ] Confirm Hard-mode AI is unbeatable and move-for-move identical to the other platform away
      from documented ties
- [ ] Confirm every localized string (`en` and `ja`) renders correctly on both apps
- [ ] Confirm every placed mark is a `GKEntity`/`GKSKNodeComponent` (not a directly-added node) on
      both apps, with no stale entities left after New Game
- [ ] Side-by-side screenshots/recording of both apps for the README

## Phase 5 — Polish (stretch, optional)

Not required for the parity story in Phase 4; only pursued if the MVP above is solid first.

- [ ] Win-particle burst (`SKEmitterNode`)
- [ ] Tap/win sound effects (`SKAudioNode` / `SKAction.playSoundFileNamed`)
- [ ] App icons

## Phase 6 — Documentation & release

- [ ] README updated with screenshots/GIFs of both apps side by side
- [ ] This file's phase checkboxes fully checked, `## Status` in `CLAUDE.md` updated to match
- [ ] Tag `v0.1.0` once Phases 0–4 are complete and verified

## Explicitly out of scope

- Persistence (win/loss record across app launches), accounts, networking/multiplayer — see
  `docs/GAME_DESIGN.md`'s "Deliberately out of scope for the MVP"
- Any SpriteKit/GameplayKit subsystem not motivated by Tic-Tac-Toe itself (physics, tile maps,
  camera/crop, shaders, pathfinding, agents/steering, noise, spatial partitioning) — exercising
  them here would be arbitrary rather than driven by the game, and the OSS libraries already cover
  those subsystems' own parity in their own READMEs/test suites
