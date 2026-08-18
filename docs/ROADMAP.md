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

**Complete.** Both code-level/automated-test verification and an on-device visual pass (iOS
Simulator `iPhone 16`/iOS 18.5, Android Emulator `tictactoe_test`) are done, at both `en` and `ja`
locales, for all three difficulties.

- [x] Walk the full checklist in `docs/GAME_DESIGN.md`'s "Parity checklist" section against both
      apps. Code-level pieces (AI strategist config, `gameModelUpdates(for:)` ascending tie-break
      order, the `en`/`ja` string tables, entity wiring) are covered by the items below; the visual
      pass drove full games (menu → difficulty pick → coin toss → placing marks → block/win/draw →
      score row → New Game) on both an iOS Simulator and an Android Emulator at `en` and `ja`,
      screenshotting each step. Grid/mark/button layout, colors, and the `crossFade`
      `MenuScene`→`GameScene`/New Game transition all matched. One real, non-obvious difference
      observed and accepted rather than fixed: at the same nominal point size, iOS's default system
      font (San Francisco) renders visibly thinner than Android's (Roboto) for the Latin `en`
      strings — Japanese glyphs on both platforms read close in weight since CJK faces are
      inherently heavier at a given size. Colors/values are identical (`fontColor` is `.white`/
      `Color.WHITE` on both); the visible difference is each OS's own font rendering, not something
      this app controls, so it's recorded here rather than chased.
      **Real bug found and fixed by this pass:** Android's `score_row` string
      (`X: %1$d  O: %2$d  Draws: %3$d`) rendered with single spaces between segments instead of the
      double spaces `docs/GAME_DESIGN.md`'s Localization table specifies and iOS's
      `Localizable.xcstrings` already renders correctly — confirmed via `aapt dump strings` that
      Android's resource compiler collapses a run of 2+ literal whitespace characters in a plain
      string resource down to one, a well-known Android/AAPT behavior with no iOS equivalent (`.xcstrings`
      preserves whitespace exactly as authored). Fixed in both
      `android/app/src/main/res/values/strings.xml` and `values-ja/strings.xml` by escaping the
      second space of each pair as `\u0020`, which survives the collapse; re-verified byte-identical
      to iOS via `aapt dump strings` after rebuilding, and visually confirmed on the emulator.
- [x] Confirm Hard-mode AI is unbeatable and move-for-move identical to the other platform away
      from documented ties. `TicTacToeHardStrategistTests`/`Test` (Phase 1) already prove Hard
      never loses on each platform independently; added
      `TicTacToeHardStrategistParityTests`/`Test` on both platforms, asserting
      `GKMinmaxStrategist.bestMoveForActivePlayer()` picks the identical cell at four hand-verified
      unambiguous positions (the opening move, the reply to a corner opening, and two "block the
      only threat or lose" positions) — all pass on both platforms.
      **Investigation finding, not an OSS/Apple discrepancy:** an earlier version of this test
      compared entire played-out game move traces and found iOS and Android diverging partway
      through a game. Investigating showed this wasn't a strategist bug: `score(for:)` has no depth
      discount (`+1`/`-1`/`0` regardless of how many turns a win takes — see
      `docs/GAME_DESIGN.md`'s "Game model" section), so once Hard has a forced win available, a
      move that builds a fork scores identically to a move that wins immediately — a genuine tie
      outside what the "strictly-best-move" parity guarantee promises, not a bug. The test was
      redesigned around unambiguous positions instead of full-game traces for exactly this reason.
- [x] Confirm every localized string (`en` and `ja`) renders correctly on both apps. The `en`/`ja`
      string tables themselves are byte-identical to `docs/GAME_DESIGN.md`'s Localization table on
      both platforms (`ios/TicTacToe/Resources/Localizable.xcstrings` vs.
      `android/app/src/main/res/values{,-ja}/strings.xml` — the latter only after the `score_row`
      fix above). Every key confirmed rendering correctly on-screen, both locales, both apps, via
      the visual pass above: `menu_title`/`difficulty_*` on `MenuScene`; `status_your_turn`/
      `status_cpu_thinking`/`status_you_win`/`status_cpu_wins`/`status_draw`/`score_row`/
      `new_game` on `GameScene`, reached by playing full games (including deliberately losing, to
      surface `status_cpu_wins`, and playing to a forced draw, to surface `status_draw`). No
      truncation, wrapping, or missing-glyph boxes at either locale on either platform.
- [x] Confirm every placed mark is a `GKEntity`/`GKSKNodeComponent` (not a directly-added node) on
      both apps, with no stale entities left after New Game. iOS: confirmed by code
      (`GameScene.placeMark`/`TicTacToeMarkEntity`) and by two new
      `GameScenePlaythroughTests` cases — every human-placed mark is a `GKEntity` with a
      `GKSKNodeComponent` wrapping its node in `gkScene.entities`, and a fresh New Game's
      `gkScene.entities` is empty (`gkScene` exposed test-internal for this, same convention as
      `match`/`statusLabel`/`scoreLabel`). Android: confirmed by the same code-level review of
      `GameScene.placeMark`/`TicTacToeMarkEntity.kt` (identical shape to iOS); an equivalent
      automated `GameScene`-level test isn't currently possible without adding Robolectric (plain
      JVM unit tests can't construct a real `android.graphics.Path`-backed `GameScene`), so this
      stays a manual/code-review confirmation on this platform rather than an automated test.
- [x] Side-by-side screenshots/recording of both apps for the README. Captured during the visual
      pass above: menu (`en`/`ja`), an in-progress board, a forced draw, and a CPU win, on both
      platforms. Curating these into the actual README side-by-side layout is Phase 6's job (README
      updated with screenshots/GIFs) — this item is the capture, not the publication.

## Phase 5 — Polish (stretch, optional)

**Complete.** Not required for the parity story in Phase 4, but both `bitzgroup/SpriteKit`
(`SKEmitterNode`, `SKAudioNode`/`playSoundFileNamed`) already implemented everything needed, so all
three stretch items landed on both platforms. See `docs/GAME_DESIGN.md`'s new "Polish (Phase 5)"
section for the full spec each implementation is written against.

- [x] Win-particle burst (`SKEmitterNode`) — fires alongside the existing win-line pulse, one
      emitter per winning cell, particle texture rendered at runtime (a small white circle) rather
      than an imported image asset, auto-removed after its burst finishes. Verified on both an iOS
      Simulator and an Android Emulator: triggers on a CPU win with no crash, and the full test
      suites (23 iOS / 20 Android) still pass with the emitter code running inline in
      `handleGameOver()`.
- [x] Tap/win sound effects (`SKAudioNode` / `SKAction.playSoundFileNamed`) — `tap.mp3` on every
      placed mark, `win.mp3` on a decided game (not a draw); both files synthesized (sine-tone
      generation, not sourced) so they're license-free, then encoded to MP3 — the one format both
      platforms decode natively with no extra plumbing (Ogg Vorbis has no iOS decoder at all; Opus
      on iOS only decodes from a `.caf` container, not the `.opus`/Ogg-Opus files standard encoders
      produce, which would mean two different container files per sound and no true byte-identical
      asset — see `docs/GAME_DESIGN.md`'s "Polish (Phase 5)" section for the full comparison).
      Byte-identical between `ios/TicTacToe/Resources/Sounds/` and `android/app/src/main/assets/`
      (confirmed via `md5`).
      **Real bug found and fixed by on-device verification, not just a successful build:** the
      first Android implementation passed `"file:///android_asset/tap.wav"` to
      `playSoundFileNamed`, following the commonly-cited trick for playing APK assets via
      `MediaPlayer` — it built and ran clean, but on-device logcat showed `MediaPlayer error
      (-38, 0)` and no audible sound, silently swallowed by `SKMediaPlayerHandle`'s own
      `runCatching` wrapper around every native call (safe-by-design against crashing the render
      thread, but that also means a failure here has zero build-time or test-time signal). Fixed by
      having `GameScene` copy each asset to `Context.getCacheDir()` once per launch and pass that
      real absolute path instead.
      **Second finding: logcat alone wasn't sufficient verification either.** After the fix, the
      Android Emulator logged no more `MediaPlayer error` lines, but genuinely played no audible
      sound (confirmed by ear) — while the same build was clearly audible on the iOS Simulator. AVD
      config (`hw.audioOutput=yes`), the device's `STREAM_MUSIC` volume/mute state, and the host
      Mac's own output volume all checked out fine, pointing at the emulator's own QEMU/host audio
      passthrough (a known rough edge on Apple Silicon Mac hosts) rather than the app or
      `bitzgroup/SpriteKit`. Confirmed by re-testing on a physical device (Pixel 4a) — audible there,
      matching iOS. Same lesson as Phase 2's `GameScene` visual verification needing a physical
      device over the emulator: some fidelity gaps only the emulator has, and only a physical device
      settles them. `docs/GAME_DESIGN.md`'s spec was corrected to describe the real playback
      mechanism instead of the assumption that turned out wrong.
- [x] App icons — both platforms ship the same design (`#1A1A1A` background, white 2×2 grid,
      `GameScene`'s own board motif). iOS: added a 1024×1024 single-size `AppIcon.appiconset` (no
      icon existed before this phase). Android: upgraded from a flat non-adaptive vector to a real
      adaptive icon (`mipmap-anydpi-v26` background/foreground layers, foreground grid inset to the
      adaptive-icon safe zone) with a legacy `mipmap/ic_launcher(_round).xml` fallback for API
      24–25 (`minSdk = 24`, below adaptive icons' API 26 floor). Verified on an Android Emulator
      home screen — the system correctly derived a themed/monochrome icon from the foreground
      layer's alpha channel with no explicit `<monochrome>` layer needed.

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
