# Roadmap

Phased implementation plan for the iOS and Android Tic-Tac-Toe apps described in
[`docs/GAME_DESIGN.md`](GAME_DESIGN.md) and [`docs/ARCHITECTURE.md`](ARCHITECTURE.md). Each phase
is implemented on **both platforms before moving to the next phase**, so the two apps never drift
far apart in capability — that running-side-by-side comparison is the entire point of this repo.

**Within each phase, iOS is implemented and verified first, then Android.** iOS runs against
Apple's real, official frameworks, so a phase's iOS half — once it builds and its tests pass — is
ground truth for exactly how that phase's APIs actually behave. Implementing Android second against
that already-verified reference is what makes this repo useful as a *check* on the OSS ports, not
just a demo: any place `bitzgroup/SpriteKit`/`GameplayKit`/`GKSKBridge`'s API shape or behavior
doesn't yet match Apple's real one surfaces immediately as "the Android port of code that already
works on iOS doesn't compile/behave the same," rather than staying latent. See
`docs/ARCHITECTURE.md`'s "Verifying parity" section for where discrepancies found this way get
recorded and fixed — the `spritekit-compose`/`GKSKBridge` nested-project-path bug found during
Phase 0 is the first example.

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

- [x] `TicTacToeBoard`: pure rules, no GameplayKit dependency — 9-cell state, move legality/
      application, win/loss/draw detection (all 8 lines), matching the FourInARow-precedent split
      in `docs/GAME_DESIGN.md`'s "Game model" section. Also owns `unapplyMove(at:)` — see below.
- [x] Unit tests directly against `TicTacToeBoard`: win detection (all 8 lines), loss detection,
      draw detection, legal-move generation at various board states — on both platforms, no
      GameplayKit fixture needed (8 tests per platform)
- [x] `TicTacToePlayer` (`GKGameModelPlayer`), `TicTacToeMove` (`GKGameModelUpdate`)
- [x] `TicTacToeGameModel` (`GKGameModel`): wraps `TicTacToeBoard`, adds `copy()`/
      `setGameModel(_:)`, `gameModelUpdates(for:)` (ascending cell-index order — see the tie-break
      note in `docs/GAME_DESIGN.md`), `apply(_:)`, `score(for:)`, `isWin(for:)`, `isLoss(for:)`
- [x] Unit test: `TicTacToeGameModel.copy()` independence (mutating the copy never affects the
      original) — on both platforms (6 `TicTacToeGameModel` tests per platform total)
- [x] AI difficulty wiring: Easy (`GKRandomDistribution`), Normal (`GKMonteCarloStrategist`,
      `budget = 200`), Hard (`GKMinmaxStrategist`, `maxLookAheadDepth = 9`)
- [x] Unit test: Hard AI never loses, across a representative set of opening/mid-game board states
      — on both platforms. **iOS finding, later closed on both platforms:** this test caught a
      real bug in the first iOS implementation — a no-op `unapplyGameModelUpdate` corrupted the
      shared model mid-search and crashed, because Apple's real `GKMinmaxStrategist` backtracks
      via `unapplyGameModelUpdate` instead of always copying, unlike `bitzgroup/GameplayKit`
      `v0.1.0` at the time. Fixed on iOS by giving `TicTacToeBoard` a real `unapplyMove(at:)`.
      Rather than leave the platforms permanently asymmetric, `bitzgroup/GameplayKit` itself was
      then revised to match Apple's real mutate-and-backtrack strategy, so `TicTacToeGameModel` on
      Android now implements the identical real `unapplyGameModelUpdate` too. See
      `docs/GAME_DESIGN.md`'s "Game model" section and `docs/ARCHITECTURE.md`'s "Finding OSS/Apple
      discrepancies" section for the full story.
- [x] `GKStateMachine`/`GKState` turn flow: `TurnBeginState`, `HumanTurnState`, `AITurnState`,
      `TurnEndState`, `GameOverState`, with `isValidNextState(_:)` gating, coordinated by a new
      `TicTacToeMatch` type (game model + human/AI seat assignment from the coin toss +
      difficulty's strategist + the state machine itself) not called out as its own file in
      `docs/ARCHITECTURE.md`'s original source-layout sketch but added there now
      (`TicTacToeMatch.swift`/`.kt`)

**All 16 unit tests pass on both platforms** (8 `TicTacToeBoard` + 7 `TicTacToeGameModel` + 1 Hard
strategist, run via `xcodebuild test` / `./gradlew :app:testDebugUnitTest`), and both apps still
build clean (`./gradlew :app:ktlintCheck :app:detekt :app:assembleDebug` /
`xcodebuild ... build`). No SpriteKit/UI wiring yet — Phase 2.

## Phase 2 — Board rendering & input (SpriteKit + GKSKBridge)

Implemented independently against Apple's `SpriteKit.framework`/`GameplayKit.framework` (iOS) and
`jp.co.bitz.spritekit`/`jp.co.bitz.spritekit.compose`/`jp.co.bitz.gkskbridge` (Android) from
`docs/GAME_DESIGN.md`'s "Presentation" and "Marks as entities" sections.

**Both platforms implemented and verified.** iOS: `xcodebuild build`/`test` green, all 16 Phase 0/1
unit tests still passing, visually confirmed via simulator screenshot — menu, empty board, the
deferred "CPU thinking…" reveal when the coin toss gives the CPU the opening move, and a placed
mark. Android: `./gradlew :app:ktlintCheck :app:detekt :app:assembleDebug :app:testDebugUnitTest`
green, same 16 tests passing, visually confirmed on a physical device — menu, `crossFade` into
`GameScene`, tap-to-place with the AI's deferred reveal, win-line-ready state, and New Game
re-presenting a fresh board via `crossFade` again.

**iOS finding, fixed upstream in `bitzgroup/GKSKBridge`:** Apple's real `GKScene.entities` is a
get-only property — entities are added via `addEntity(_:)`/`removeEntity(_:)`, not by appending to
the array directly. `bitzgroup/GKSKBridge`'s `GKScene.entities` was a plain `MutableList` (settable/
appendable directly), a real API-shape gap from Apple's own shape — fixed there to match:
`entities` is now `List<GKEntity>` (get-only), mutated via new `addEntity(_:)`/`removeEntity(_:)`
methods. `docs/GAME_DESIGN.md`'s "Marks as entities" section was corrected to match.

**Android finding, fixed upstream in `bitzgroup/SpriteKit`:** two real gaps surfaced getting
`MenuScene`/`GameScene`'s `SKTransition.crossFade` navigation working the same way on both
platforms (a scene calling `view?.presentScene(nextScene, transition)` on itself, matching iOS's
`self.view?.presentScene(_:transition:)` exactly):

1. `SKScene` had no `view: SKView?` back-reference at all — Apple's real `SKScene.view` (set by
   whichever `SKView` is presenting it, `nil` once another scene replaces it) wasn't implemented,
   so there was no way for a scene to reach its own presenting view from inside itself. Added
   `SKScene.view` (get-only from outside; `SKView.presentScene`'s two overloads now keep it in
   sync on both the outgoing and incoming scene).
2. `:spritekit-compose`'s `SKViewState.presentScene(scene: SKScene)` had no
   `presentScene(scene, transition)` overload — `docs/ARCHITECTURE.md` in that repo already
   documented this call existing on `SKViewState`, but the implementation hadn't caught up. Added
   the missing overload, delegating to the wrapped classic `SKView`'s own transition-aware
   `presentScene`, matching what that doc already promised.

**Android finding, fixed in this repo's own app code (not an OSS/Apple discrepancy — a bug in this
app's Kotlin port):** `TicTacToeBoard` is a Kotlin `class` (a reference type) on Android, unlike
iOS's Swift `struct` (a value type). `GameScene`'s "diff the board before/after to find the AI's
newly-occupied cell" logic (needed because `AITurnState.didEnter` applies the AI's move
synchronously — see Phase 1) relied on `val boardBefore = match.gameModel.board` capturing an
independent snapshot, which is true on iOS (struct, copied on assignment) but not on Android (class
reference — `boardBefore` silently aliased the same mutable object `match.start()`/
`applyHumanMove` go on to mutate in place, making the diff always come up empty). Fixed by using
`TicTacToeBoard.copy()` (already existed, used elsewhere for `GKGameModel.copy()`) to take a real
snapshot. Caught by visual testing on a real device (the AI's move was applied to the model but
never rendered) rather than by a unit test — a good argument for adding a `GameScene`-level test
around this diffing logic if Phase 4's parity pass has room for one.

- [x] `GameScene`: 3×3 grid (`SKShapeNode` strokes), 9 tappable per-cell `SKShapeNode`s
- [x] `GameScene` owns a `GKScene` (`rootNode` = itself); `TicTacToeMarkEntity` (`GKEntity`) +
      `TicTacToeMarkComponent` (`GKComponent`) + `GKSKNodeComponent` per placed mark, handed to the
      `GKScene` via `addEntity(_:)` — see `docs/GAME_DESIGN.md`'s "Marks as entities" section
- [x] `X`/`O` marks as stroked `SKShapeNode` paths (not label glyphs — see the rationale in
      `docs/GAME_DESIGN.md`), owned by their entity's `GKSKNodeComponent`, placement pop-in
      `SKAction`
- [x] Status `SKLabelNode` (turn / thinking / result) and score row (`X` / `O` / `Draws`,
      in-memory only)
- [x] Win-line pulse animation on the three winning cells
- [x] `MenuScene`: difficulty picker, coin toss, `SKTransition.crossFade` into `GameScene`
- [x] New Game: re-present a fresh `GameScene` via `SKTransition.crossFade`
- [x] Wire `HumanTurnState`'s tap handling and `AITurnState`'s "thinking" delay (Phase 1) into the
      scene
- [x] Localization: `en` base + `ja` translation for every key in `docs/GAME_DESIGN.md`'s
      Localization table (iOS: `Localizable.xcstrings`; Android: `values/strings.xml` +
      `values-ja/strings.xml`) — no label hardcoded into a scene

## Phase 3 — Platform app shells

- [x] iOS: `TicTacToeApp.swift` presents `MenuScene` at launch inside an `SKView`/`SpriteView`
- [x] Android: `MainActivity.kt` presents `MenuScene` at launch inside `spritekit-compose`'s
      `SKView`
- [x] Both apps are playable start-to-finish end to end (menu → game → win/loss/draw → new game)
      at all three difficulties. **iOS:** `GameScenePlaythroughTests.swift` (new), driving
      `GameScene` end to end via `CellNode.touchesBegan` directly — real OS-level touch simulation
      isn't available in a unit test target, but this exercises the actual production path
      (`HumanTurnState.applyHumanMove` → `GKStateMachine` cascade → `AITurnState`) at all three
      difficulties, asserting each reaches `board.isGameOver`, plus a New Game check. Required
      loosening `GameScene.match`/`statusLabel`/`scoreLabel` from `private` to internal for test
      visibility (`@testable import`) — no behavior change. Note: `AITurnState`'s move applies to
      `match` synchronously (Phase 1), but revealing it is deferred via `SKAction.wait` (Phase 2),
      driven by a real `SKView` frame loop this headless test has none of — so a game that ends on
      the AI's move doesn't fire `handleGameOver()`/update `statusLabel` within the test itself,
      even though `match`'s model state is already correctly terminal; that visual reveal path was
      separately verified via simulator screenshots when Phase 2 landed. **Android:** verified
      manually on a physical device — all three difficulties played to a real terminal outcome (Easy:
      human win, Normal/Hard: CPU win) via actual touch input, each followed by a working New Game
      (fresh board, `humanMark`/`difficulty` preserved, running score carried forward correctly).

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
