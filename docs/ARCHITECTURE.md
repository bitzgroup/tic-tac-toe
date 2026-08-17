# Architecture

## Purpose

This repository is a **sample, not a library**: it exists to show, side by side, that
[bitzgroup/SpriteKit](https://github.com/bitzgroup/SpriteKit),
[bitzgroup/GameplayKit](https://github.com/bitzgroup/GameplayKit), and
[bitzgroup/GKSKBridge](https://github.com/bitzgroup/GKSKBridge) — Kotlin/Android ports of Apple's
SpriteKit and GameplayKit frameworks, plus the bridging surface between them — behave the same as
the real, official frameworks they mirror. It does that by implementing the *same* small game,
Tic-Tac-Toe, twice: once as a native iOS app on Apple's own SpriteKit + GameplayKit, and once as an
Android app on the OSS ports. See [`docs/GAME_DESIGN.md`](GAME_DESIGN.md) for the one game spec
both implementations follow, and each OSS repo's own `docs/API_COMPATIBILITY.md` for exactly where
their APIs are (and, rarely, aren't) shaped like Apple's.

This is also *why* the sample lives in its own repository rather than inside any of the three OSS
repos: `bitzgroup/SpriteKit` and `bitzgroup/GameplayKit` are meant to be embedded into host apps as
git submodules and deliberately contain no app/demo module of their own (see each repo's
`docs/ROADMAP.md`, "Explicitly Out of Scope" / Phase 11), and `bitzgroup/GKSKBridge` follows the
same policy (see its own `CLAUDE.md`, "Reference: sibling repo conventions"). This repo is that
host app — one of potentially several, since nothing here is specific to Tic-Tac-Toe as far as the
three libraries are concerned.

**Why a third library, GKSKBridge, alongside SpriteKit and GameplayKit:** on Apple platforms,
GameplayKit and SpriteKit are both system frameworks, so the parts of each that reference the other
(`GKSKNodeComponent`-style entity-component ↔ scene-graph binding, a `GKAgent` steering an
`SKNode`'s position) cost nothing extra to depend on. On Android, GameplayKit and SpriteKit are
separate OSS libraries that are each meant to be usable standalone — bridging code doesn't belong
in either one, since that would force a project that only needs one of them to also pull in the
other. GKSKBridge holds that bridging surface on its own, and this app is one of the projects that
actually needs it: every placed mark is a `GKEntity` wrapped by a `GKSKNodeComponent`, held in a
`GKScene` (see `docs/GAME_DESIGN.md`'s "Marks as entities" section for the full design and
rationale) — the standard entity/node-binding idiom Xcode's own SpriteKit-plus-GameplayKit project
template generates. `GKAgent`/`GKAgentDelegate` steering and `GKAgentNodeComponent` — GKSKBridge's
other documented feature — are *not* used here: Tic-Tac-Toe marks are placed, not moved.

`bitzgroup/GKSKBridge` [released `0.1.0`](https://github.com/bitzgroup/GKSKBridge/releases/tag/0.1.0)
with its full `docs/ROADMAP.md` plan complete: `GKSKNodeComponent`, `SKNode.entity`, `GKScene`, and
`GKAgentNodeComponent` are implemented, tested, and documented — see its own `README.md`/
`CLAUDE.md` for the full API. Its Gradle module is `:gkskbridge` (package `jp.co.bitz.gkskbridge`),
matching `SpriteKit`'s `:spritekit` and `GameplayKit`'s `:gameplaykit` in shape.

## Repository layout

```text
tic-tac-toe/
├── docs/                    # this document, GAME_DESIGN.md, ROADMAP.md
├── ios/
│   └── TicTacToe/           # Xcode project — Swift, Apple's own SpriteKit + GameplayKit
└── android/
    ├── app/                 # Jetpack Compose host app — Kotlin
    ├── SpriteKit/           # git submodule → github.com/bitzgroup/SpriteKit
    ├── GameplayKit/         # git submodule → github.com/bitzgroup/GameplayKit
    ├── GKSKBridge/          # git submodule → github.com/bitzgroup/GKSKBridge
    └── settings.gradle.kts  # includes :app plus all three submodules' library modules
```

The two platform directories are siblings and neither depends on the other; there is no shared
code between them (Swift and Kotlin can't share source here), only a shared *design* — everything
that must stay in sync between them is written down once in `docs/GAME_DESIGN.md` instead.

## iOS app (`ios/`)

- A standard Xcode project/app target, Swift, targeting Apple's own `SpriteKit` and `GameplayKit`
  system frameworks directly (`import SpriteKit`, `import GameplayKit`) — no third-party
  dependencies, no package manager needed beyond what Xcode provides.
- Deployment target: iOS 15+ (a conservative, adjustable floor — nothing in this game needs a
  newer SpriteKit/GameplayKit feature).
- App shell: a SwiftUI `App` presenting an `SKView` (directly, or via `SpriteView` — either hosts
  the same `MenuScene`/`GameScene` from `docs/GAME_DESIGN.md`).
- **Project file generation:** `ios/TicTacToe/project.yml` ([XcodeGen](https://github.com/yonaskolb/XcodeGen)
  spec) is the source of truth for the `.xcodeproj`'s targets/settings — regenerate after adding
  files with `xcodegen generate` (run from `ios/TicTacToe/`). XcodeGen itself is a dev-time-only
  tool (not an app dependency, not linked into the binary); the generated `.xcodeproj` is committed
  alongside `project.yml` so anyone without XcodeGen installed can still open and build the project
  directly in Xcode.
- Suggested source layout inside the app target:

  ```text
  TicTacToe/
  ├── TicTacToeApp.swift        # SwiftUI App entry point, hosts the SKView
  ├── Game/                     # GameplayKit layer
  │   ├── TicTacToeBoard.swift         # rules only — no GameplayKit dependency (see GAME_DESIGN.md)
  │   ├── TicTacToePlayer.swift        # GKGameModelPlayer
  │   ├── TicTacToeMove.swift          # GKGameModelUpdate
  │   ├── TicTacToeGameModel.swift     # GKGameModel, wraps TicTacToeBoard
  │   ├── States/                      # GKState subclasses (TurnBeginState, HumanTurnState, ...)
  │   └── Entities/                    # GKEntity/GKComponent — needs GKSKBridge, see GAME_DESIGN.md
  │       ├── TicTacToeMarkEntity.swift     # GKEntity: one per placed mark
  │       └── TicTacToeMarkComponent.swift  # GKComponent: player + cellIndex
  ├── Scenes/                   # SpriteKit layer
  │   ├── MenuScene.swift
  │   └── GameScene.swift
  └── Resources/
      └── Localizable.xcstrings # String Catalog, en base + ja — see "Localization" below
  ```

- **Localization:** a String Catalog (`Localizable.xcstrings`) holding the `en` base strings plus a
  full `ja` translation, one entry per key in `docs/GAME_DESIGN.md`'s Localization table. Scenes
  look up every label via `String(localized:)` — nothing is a literal string in `MenuScene`/
  `GameScene`. Xcode picks the active language from the device/simulator's system language
  automatically; no in-app switcher.

## Android app (`android/`)

- A standard Gradle Android project. The host app module is `:app`, a Jetpack Compose app (per
  `bitzgroup/SpriteKit`'s own documented recommendation to use its `:spritekit-compose` module
  rather than the classic `View`/XML path).
- `SpriteKit`, `GameplayKit`, and `GKSKBridge` are all **git submodules**, embedded exactly the way
  `SpriteKit`/`GameplayKit`'s own READMEs document for host apps — not published/consumed as Maven
  artifacts:

  ```kotlin
  // android/settings.gradle.kts
  include(":app")

  include(":SpriteKit:spritekit", ":SpriteKit:spritekit-compose")
  project(":SpriteKit:spritekit").projectDir = file("SpriteKit/spritekit")
  project(":SpriteKit:spritekit-compose").projectDir = file("SpriteKit/spritekit-compose")

  include(":GameplayKit:gameplaykit")
  project(":GameplayKit:gameplaykit").projectDir = file("GameplayKit/gameplaykit")

  include(":GKSKBridge:gkskbridge")
  project(":GKSKBridge:gkskbridge").projectDir = file("GKSKBridge/gkskbridge")
  ```

  ```kotlin
  // android/app/build.gradle.kts
  dependencies {
      implementation(project(":SpriteKit:spritekit-compose"))
      implementation(project(":GameplayKit:gameplaykit"))
      implementation(project(":GKSKBridge:gkskbridge"))
  }
  ```

  GKSKBridge's own `gkskbridge/build.gradle.kts` depends on `:GameplayKit:gameplaykit` and
  `:SpriteKit:spritekit` via the same kind of project-path reference — it carries no submodules of
  its own (see its `docs/ARCHITECTURE.md`), so those two project paths must exist under those exact
  names in whichever `settings.gradle.kts` includes it, which the include block above guarantees.
  All three submodules' Gradle version catalogs (`agp` 8.5.2, `kotlin` 2.0.20, `detekt` 1.23.6,
  `ktlint-gradle` 12.1.1) agree, so `android/gradle/libs.versions.toml` can declare one shared set
  of versions/plugins for the whole build — Gradle only reads the *including* project's version
  catalog, not each submodule's own `gradle/libs.versions.toml`, so this repo's own catalog is what
  actually governs versions once they're included here.

- Suggested source layout inside `:app` (deliberately mirroring the iOS layout above, package by
  package, so the two are easy to compare file-for-file):

  ```text
  app/src/main/
  ├── kotlin/jp/co/bitz/tictactoe/
  │   ├── MainActivity.kt           # hosts the Compose SKView (:spritekit-compose)
  │   ├── game/                     # GameplayKit layer
  │   │   ├── TicTacToeBoard.kt           # rules only — no GameplayKit dependency
  │   │   ├── TicTacToePlayer.kt          # GKGameModelPlayer
  │   │   ├── TicTacToeMove.kt            # GKGameModelUpdate
  │   │   ├── TicTacToeGameModel.kt       # GKGameModel, wraps TicTacToeBoard
  │   │   ├── states/                     # GKState subclasses
  │   │   └── entities/                   # GKEntity/GKComponent — needs GKSKBridge, see GAME_DESIGN.md
  │   │       ├── TicTacToeMarkEntity.kt       # GKEntity: one per placed mark
  │   │       └── TicTacToeMarkComponent.kt    # GKComponent: player + cellIndex
  │   └── scenes/                   # SpriteKit layer
  │       ├── MenuScene.kt
  │       └── GameScene.kt
  └── res/
      ├── values/strings.xml       # en base strings — see "Localization" below
      └── values-ja/strings.xml    # ja translations, same keys
  ```

- `minSdk` 24 / `compileSdk`/`targetSdk` 34, Kotlin 2.0+ — matching the submodules' own
  `Requirements` so the app and its dependencies always build against the same SDK/Kotlin baseline.
- **Localization:** `res/values/strings.xml` holds the `en` base strings (Android's default
  resource set doubles as the base locale) and `res/values-ja/strings.xml` overrides them with a
  full `ja` translation, one entry per key in `docs/GAME_DESIGN.md`'s Localization table. Scenes
  look up every label via `context.getString(R.string.…)` (or `stringResource(R.string.…)` from the
  Compose host) — nothing is a literal string in `MenuScene`/`GameScene`. Android picks the active
  resource set from the device's system language automatically; no in-app switcher.

### Working with the submodules

**During this active co-development period, all three submodules track their `develop` branch**
(`.gitmodules`' `branch = develop`, set via `git submodule set-branch --branch develop <path>`)
rather than being pinned to a release tag — tic-tac-toe's own implementation is currently the
fastest way real gaps in the three libraries surface (see the `spritekit-compose`/`GKSKBridge`
nested-project-path bug found and fixed while scaffolding Phase 0), so tracking `develop` lets
fixes flow in without a formal release cycle each time. Once the three libraries and this app are
all stable, switch back to pinning each submodule to a specific release tag (`git submodule set-branch
--branch '' <path>` — an empty branch name reverts to the default detached-at-a-fixed-commit
behavior) for reproducible builds.

```sh
# first checkout
git clone --recurse-submodules git@github.com:bitzgroup/tic-tac-toe.git

# already cloned without --recurse-submodules
git submodule update --init --recursive

# pull in upstream changes to any of the three libraries later (checks out each submodule's
# develop branch tip, per the tracking config above)
git submodule update --remote android/SpriteKit
git submodule update --remote android/GameplayKit
git submodule update --remote android/GKSKBridge
```

## Why two GameplayKit strategists and not just one

`docs/GAME_DESIGN.md`'s three difficulty levels (`GKRandomDistribution` / `GKMonteCarloStrategist`
/ `GKMinmaxStrategist`) aren't just a UX nicety — they're chosen specifically because they exercise
three independently-portable pieces of GameplayKit's game-AI surface (randomization, Monte Carlo
tree search, and minmax with alpha-beta pruning) in one small app, which is a better parity
demonstration than only ever calling the one strategist a solved game like Tic-Tac-Toe strictly
needs (`GKMinmaxStrategist` alone would suffice to make the AI unbeatable).

## Verifying parity

There's no automated cross-platform test that runs both apps and diffs their output — Swift and
Kotlin apps can't share a test runner. Parity is instead verified manually against the checklist in
`docs/GAME_DESIGN.md`, plus each platform's own unit tests for its `TicTacToeBoard` (win/loss/draw
detection, legal-move generation — pure rules, no GameplayKit dependency, so these tests need no
GameplayKit fixture at all) run independently in each app's own test suite, the same split
[FourInARow](https://developer.apple.com/library/archive/samplecode/FourInARow/Introduction/Intro.html)
uses for its own `FourInARowTests`:

- iOS: XCTest, run via Xcode or `xcodebuild test`.
- Android: JUnit via `./gradlew testDebugUnitTest`, run from `android/`.

See `docs/ROADMAP.md` Phase 4 for when this happens in the implementation plan.
