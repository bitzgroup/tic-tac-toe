# Game design

This document specifies Tic-Tac-Toe's rules, AI, and presentation **once, platform-agnostically**.
Both the iOS app (Apple's official SpriteKit + GameplayKit) and the Android app
([bitzgroup/SpriteKit](https://github.com/bitzgroup/SpriteKit) +
[bitzgroup/GameplayKit](https://github.com/bitzgroup/GameplayKit) +
[bitzgroup/GKSKBridge](https://github.com/bitzgroup/GKSKBridge)) implement this same spec. Any
place the two platforms must necessarily differ (framework-specific class names, non-bit-identical
algorithms) is called out explicitly below instead of left to drift.

The whole point of this repository is that a reader can put the two apps side by side and see the
same game behave the same way — so the design stays intentionally small and free of anything that
would obscure that comparison (no persistence, no networking, no accounts).

## Rules

Standard 3×3 Tic-Tac-Toe. Board cells are indexed 0–8, row-major:

```text
0 | 1 | 2
--+---+--
3 | 4 | 5
--+---+--
6 | 7 | 8
```

Two players, `X` and `O`, alternate placing a mark on an empty cell. The game ends when one player
has three marks in a row/column/diagonal (a **win**, the other player **loses**), or all nine cells
are filled with no winner (a **draw**). There are 8 winning lines: 3 rows, 3 columns, 2 diagonals.

One player is always human (played via touch); the other is always the on-device AI. At the start
of each game, a coin toss (see [Randomization](#randomization-easy-ai--coin-toss)) decides whether
the human plays `X` (moves first) or `O` (moves second) — this is the app's only source of
variation between games at a given difficulty, since the rules and AI are otherwise deterministic
or bounded-random per the difficulty level below.

## GameplayKit layer

This is the part both libraries mirror class-for-class — same protocol/interface names, same
method names, same responsibilities on both platforms (see
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) for the exact Swift/Kotlin type mapping).

### Game model

Apple's own reference documentation for
[`GKStrategist.gameModel`](https://developer.apple.com/documentation/gameplaykit/gkstrategist/gamemodel)
uses this exact game as its illustration of what a game model is: *"the game model class for a
Tic-Tac-Toe game would encode the locations of X and O marks currently on the board and which
player's turn is next."* That sentence is this section's spec, verbatim — `TicTacToeBoard`/
`TicTacToeGameModel` below encode exactly that and nothing more.

Structurally, this follows Apple's own real sample for `GKMinmaxStrategist`,
[FourInARow](https://developer.apple.com/library/archive/samplecode/FourInARow/Introduction/Intro.html)
(a Connect-Four-style game, UIKit rather than SpriteKit, but the closest official precedent for
*how to structure* a `GKGameModel`): a plain, GameplayKit-independent board type holds the actual
rules, and a thin adapter type layers `GKGameModel` conformance on top of it — rather than baking
protocol conformance directly into the rules type. This keeps the rules unit-testable without
GameplayKit in the loop at all, mirroring FourInARow's own `AAPLBoard` (rules) /
`AAPLMinmaxStrategy` (GameplayKit adapter) split:

- **`TicTacToeBoard`** — the actual rules, no GameplayKit dependency: a 9-element array of
  `Mark?` (`.x`/`.o`/empty) plus whose turn it is. Owns move legality, applying a move, and
  win/loss/draw detection against the 8 winning lines above. This is the type
  [Rules](#rules) above describes, and the direct unit-test target for the checklist in Phase 1 of
  `docs/ROADMAP.md`.
- **`TicTacToeGameModel`** — conforms to `GKGameModel` (Apple's protocol on iOS; the OSS `interface
  GKGameModel` in `jp.co.bitz.gameplaykit` on Android — the two are shaped identically: `players`,
  `activePlayer`, `copy()`/`setGameModel(_:)`, `gameModelUpdates(for:)`, `apply(_:)`,
  `score(for:)`, `isWin(for:)`, `isLoss(for:)`) by wrapping a `TicTacToeBoard` and delegating to
  it:
  - **`players`:** two fixed `TicTacToePlayer`s, `playerId` 0 (`X`) and 1 (`O`).
  - **`gameModelUpdates(for:)`:** one `TicTacToeMove` per empty cell the board reports, or
    `nil`/`null` if it isn't that player's turn or the game has already ended.
  - **`apply(_:)`:** delegates to `TicTacToeBoard`'s own move-application, then advances
    `activePlayer` to the other player.
  - **`score(for:)`:** `+1` if `player` has won, `-1` if `player` has lost, `0` otherwise — the
    simplest possible heuristic, sufficient here because `GKMinmaxStrategist` searches the
    *entire* game tree (9 plies) rather than needing a mid-game evaluation function.
  - **`isWin(for:)` / `isLoss(for:)`:** delegate straight to `TicTacToeBoard`.
  - **`copy()` must be a true deep copy** (deep-copies the wrapped `TicTacToeBoard`) — required by
    `GKGameModel`/`NSCopying` conformance on both platforms regardless of the point below, even
    though neither strategist calls it during search anymore (see next point).
  - **`apply(_:)`/`unapplyGameModelUpdate(_:)` must be true inverses of each other, identically on
    both platforms.** Both `GKMinmaxStrategist` and `GKMonteCarloStrategist` — on iOS (Apple's real
    frameworks) *and* on Android (`bitzgroup/GameplayKit`) — search by mutating the one shared
    model in place: `apply` a candidate move, recurse/roll out, `unapplyGameModelUpdate` it back
    off before trying the next one, rather than branching by copying at every node. `TicTacToeMove`
    delegates to `TicTacToeBoard`'s own `unapplyMove(at:)` (clears the cell, reverts `activeMark`)
    on both platforms.
    **This wasn't always symmetric — a real Apple/OSS discrepancy this app's own Phase 1
    implementation found and fixed, not just documented:** `bitzgroup/GameplayKit`'s `v0.1.0`
    originally always branched by copying and never called `unapplyGameModelUpdate` at all, unlike
    Apple's real `GKMinmaxStrategist`, which documents backtracking via unapply as its own
    implementation strategy. Leaving `unapplyGameModelUpdate` a no-op (safe against `v0.1.0`) is
    exactly what broke on iOS first: this app's own Hard-mode unit tests crashed with a "cell
    already occupied" precondition failure — a stale mark left behind by a failed backtrack —
    until `TicTacToeBoard` grew a real `unapplyMove(at:)`. Rather than leave the platforms
    permanently asymmetric (a no-op-is-fine Android vs. a must-be-real iOS), `bitzgroup/GameplayKit`
    itself was revised post-`v0.1.0` to match Apple's real mutate-and-backtrack behavior, so both
    platforms now have the identical requirement — see `docs/ARCHITECTURE.md`'s "Finding OSS/Apple
    discrepancies" section for the full story, including why the fix went upstream into the library
    rather than staying a workaround in this app.

`TicTacToeMove` conforms to `GKGameModelUpdate`: just a `cellIndex` plus the mutable `value` a
strategist stamps with the move's evaluated score while it searches.

`TicTacToePlayer` conforms to `GKGameModelPlayer`: just the fixed `playerId` (0 = `X`, 1 = `O`).

### AI difficulty → GameplayKit strategist

Three difficulties, each a different, real GameplayKit AI approach — not a fake "handicap" bolted
on top:

| Difficulty | Mechanism | Behavior |
|---|---|---|
| **Easy** | `GKRandomDistribution` picks uniformly among `gameModelUpdates(for:)` | Plays legal but unplanned moves; beatable, sometimes loses. |
| **Normal** | `GKMonteCarloStrategist`, `budget = 200` | Strong but not perfect — playout-budget-limited, so occasionally misses the objectively best move; non-deterministic between games. |
| **Hard** | `GKMinmaxStrategist`, `maxLookAheadDepth = 9` | Searches the full game tree. Tic-Tac-Toe is a solved game, so this plays perfectly: it never loses, and wins whenever the human's play allows it. Deterministic given a board (module the tie-break note below). |

**Known, documented non-bit-identical case:** when multiple moves tie in minmax score (the
opening move is the classic example — corner, edge, and center all have equal-length forced-draw
lines from an empty board under naive scoring), Apple does not document its own tie-break rule, and
neither does the OSS port. Both implementations keep the *first-seen* move on a tie, and
"first-seen" depends on `gameModelUpdates(for:)`'s iteration order — which this spec fixes to
ascending cell index (0→8) on both platforms specifically so Hard-mode opening moves match. Away
from ties (any board with a strictly-better move available), both platforms' Hard AI picks the same
move, since minmax's *value* for a solved game like this is unambiguous.

### Randomization (Easy AI & coin toss)

- **Coin toss (who plays `X`):** `GKRandomSource.sharedRandom().nextBool()` — Apple ships no
  `d2()` convenience (only `d6()`/`d20()`), and a coin toss is exactly what the `GKRandom`
  protocol's `nextBool()` is documented for, so there's no need to reach for
  `GKRandomDistribution` here at all.
- **Easy-mode move choice:** `GKRandomDistribution(lowestValue: 0, highestValue: n - 1)` (`n` =
  `gameModelUpdates(for:)`'s count that turn), used to index uniformly into that move list.

Neither needs a specific seed — `GKRandomSource.sharedRandom()`'s default seeding is fine for
both, no reproducibility requirement here, unlike the OSS port's own test suite which verifies
these sources bit-for-bit/contract-conformant against Apple's algorithms independently of this
app.

### Turn flow: `GKStateMachine`

A `GKStateMachine` of five `GKState` subclasses drives one game, gating transitions via
`isValidNextState(_:)` so, e.g., a stray tap can't move the game out of `GameOverState`:

```text
TurnBeginState ──▶ HumanTurnState ──▶ TurnEndState ──▶ TurnBeginState (next turn)
       │                                    │                  │
       └──────────▶ AITurnState ────────────┘                  ▼
                                                          GameOverState
```

- **`TurnBeginState`** — looks at `activePlayer` and this game's human/AI assignment (from the
  coin toss) and immediately enters `HumanTurnState` or `AITurnState`.
- **`HumanTurnState`** — waits for a tap on an empty cell (routed in from the SpriteKit layer's
  touch handling); on a legal tap, applies the move and enters `TurnEndState`.
- **`AITurnState`** — asks the difficulty-appropriate strategist for
  `bestMoveForActivePlayer()`, applies it, and enters `TurnEndState`. A short fixed delay (see
  [Presentation](#presentation-spritekit-layer)) makes the AI's turn visible rather than instant,
  even though the search itself is fast enough not to need one.
- **`TurnEndState`** — checks `isWin`/`isLoss`/draw on the now-current model; enters
  `GameOverState` if the game ended, otherwise `TurnBeginState`.
- **`GameOverState`** — terminal for this game instance; a new game is a new scene/model/state
  machine, not a transition back out of this state.

### Marks as entities: `GKScene` + `GKEntity` + `GKSKNodeComponent`

Rather than tracking each mark's `SKShapeNode` (see [Presentation](#presentation-spritekit-layer)
below) as a bare node, placing a mark creates a `GKEntity` and hands it to a `GKScene`. This is the
one part of the app that needs [`bitzgroup/GKSKBridge`](https://github.com/bitzgroup/GKSKBridge) on
Android — binding a GameplayKit entity to a SpriteKit node is exactly the cross-framework surface
neither `SpriteKit` nor `GameplayKit` alone can own (see `docs/ARCHITECTURE.md`'s "Why a third
library" section). This mirrors the entity/component wiring Xcode's own SpriteKit-plus-GameplayKit
"Game" project template generates; neither of the two official Apple references cited above (the
`GKStrategist.gameModel` doc snippet, the FourInARow sample) happens to demonstrate it, since
neither combines SpriteKit with GameplayKit, but it's the standard idiom Apple's own tooling
produces when the two frameworks are used together — reason enough on its own for a parity sample
like this one to exercise it. The exact shape below follows `bitzgroup/GKSKBridge`'s own v0.1.0
API (which mirrors Apple's real `GKScene`/`GKSKNodeComponent` — both plain, non-magical types with
no implicit scene-graph side effects):

- **`GameScene` owns a `GKScene`** (`rootNode` set to the scene itself, `entities` starting empty).
  `entities` itself is get-only on Apple's real `GKScene` — entities are added/removed via
  `addEntity(_:)`/`removeEntity(_:)`, not by mutating the array directly.
  This is a plain container — `GKScene` does not add anything to the node tree on its own, and
  `GKSKNodeComponent` does not either: adding a `GKSKNodeComponent(node:)` to an entity only sets
  `node.entity` (and clears it again on removal) so the node can look its owning entity up, nothing
  more. `GameScene` still adds each mark's `SKShapeNode` to the tree itself via a plain `addChild`,
  the same as every other node in [Presentation](#presentation-spritekit-layer) below — entities
  don't change *how* nodes get on screen, only how they're associated with game data.
- **`TicTacToeMarkEntity`** (`GKEntity`) — one per placed mark, with two components:
  - **`GKSKNodeComponent(node:)`** — Apple's own type on iOS; `bitzgroup/GKSKBridge`'s port
    (`jp.co.bitz.gkskbridge`) on Android. Wraps the mark's `SKShapeNode`, and is what lets
    `GameScene`'s touch handling go from a tapped `SKNode` back to the `GKEntity`/
    `TicTacToeMarkComponent` that owns it (`node.entity`) — not the other way around.
  - **`TicTacToeMarkComponent`** (an ordinary `GKComponent` subclass, not part of GKSKBridge) —
    records which player (`X`/`O`) and which `cellIndex` this entity's mark belongs to. Exists to
    show an entity carrying more than just its node component, not only the bridge itself.
- On placement: create the entity, add both components, add the node to `GameScene` via `addChild`,
  hand the entity to `gkScene` via `addEntity(_:)`. On New Game: both `gkScene`'s entities and the
  node tree are discarded together with the old `GameScene` (see "New Game" below) — a new game
  never reuses an old entity.
- **`GKAgent`/`GKAgentDelegate` steering and `GKAgentNodeComponent` — GKSKBridge's other documented
  feature — are not used here.** Marks are placed, not moved; there's nothing for an agent to steer
  toward. See `docs/ROADMAP.md`'s "Explicitly out of scope."

## Presentation (SpriteKit layer)

Two scenes, both built from primitives every SpriteKit port implements (`SKScene`/`SKNode`,
`SKShapeNode`, `SKLabelNode`, `SKAction`, per-node touch dispatch, `SKTransition`) so the same
description below produces the same look on both platforms.

### `MenuScene`

- Title label ("Tic-Tac-Toe").
- Three difficulty options (Easy / Normal / Hard) as tappable `SKLabelNode`/`SKShapeNode` pairs.
- On a difficulty tap: run the coin toss, then `SKView.presentScene(_:transition:)` into
  `GameScene` with `SKTransition.crossFade(withDuration:)`, passing the chosen difficulty and
  which mark (`X`/`O`) the human plays.

### `GameScene`

- A 3×3 grid of square cells drawn with `SKShapeNode` strokes (not a background sprite/texture, so
  there's no image-asset dependency to keep in sync between the two apps).
- One invisible, tappable `SKShapeNode` per cell (9 total) with touch handling enabled on the node
  itself — exercises per-node touch dispatch on both platforms rather than a single
  scene-level touch handler with manual hit-testing.
- **Marks are vector shapes, not glyphs:** `X` is two crossing `SKShapeNode` line paths, `O` is one
  stroked circular `SKShapeNode` path. Deliberately not `SKLabelNode` text ("✕"/"○") — glyph
  rendering/metrics differ across iOS's and Android's font stacks in ways that would undercut a
  side-by-side visual comparison, while a stroked path renders identically (same size, same line
  width) on both. Each mark's `SKShapeNode` is added to the scene via a plain `addChild`, same as
  every other node here, and is also wrapped by a `TicTacToeMarkEntity`'s `GKSKNodeComponent` so
  touch handling can recover the entity/player/cell behind a tapped node — see
  [Marks as entities](#marks-as-entities-gkscene--gkentity--gksknodecomponent) above.
- **Placement animation:** each mark pops in via `SKAction.group([scale(to: 1, duration: 0.15),
  fadeAlpha(to: 1, duration: 0.15)])` from a zero-scale, zero-alpha start.
- **AI "thinking" delay:** `AITurnState` waits a fixed ~0.4s (an `SKAction.wait(forDuration:)` the
  scene runs, not a real computation delay — see [Turn flow](#turn-flow-gkstatemachine)) before
  applying its move, so Easy/Normal/Hard all feel like a turn is being taken rather than the board
  instantly flipping.
- **Win highlight:** the three winning-line marks pulse once (`SKAction.sequence([scale(to: 1.15,
  duration: 0.15), scale(to: 1, duration: 0.15)])`, repeated twice) and a status `SKLabelNode`
  announces the result ("You win!" / "CPU wins" / "Draw").
- **Status label:** always shows whose turn it is or the game result ("Your turn (X)" / "CPU
  thinking…" / "You win!" / …).
- **Score row:** three `SKLabelNode`s, `X / O / Draws`, an in-memory session counter (resets on
  app relaunch — no persistence layer, see the note at the top of this document).
- **New Game:** a tappable `SKLabelNode`/`SKShapeNode`; re-presents a freshly constructed
  `GameScene` via `SKView.presentScene(_:transition:)` (`SKTransition.crossFade`) rather than
  mutating the existing scene's nodes in place, so "new game" always starts from a genuinely clean
  `TicTacToeGameModel` + `GKStateMachine` + mark-entity list.

### Deliberately out of scope for the MVP

Listed here (rather than silently omitted) so it's clear these were a choice, not an oversight —
see `docs/ROADMAP.md`'s Phase 5 for the stretch-goal version of this list:

- Win-particle burst (`SKEmitterNode`) and tap/win sound effects (`SKAudioNode`/
  `playSoundFileNamed`) — both libraries support these, but they're not needed to demonstrate the
  core parity story and are deferred to keep the MVP small.
- Physics, tile maps, camera/crop, shaders — no relevance to a static 3×3 board game; exercising
  them here would be arbitrary rather than motivated by the game itself.
- Persistence (win/loss record across launches), accounts, networking/multiplayer.

## Localization

Every user-facing string in both apps is localized, base language **English** (`en`), with a full
**Japanese** (`ja`) localization shipped alongside it. This is UI-only — it does not change the
documentation-language rule elsewhere in this repo: `docs/GAME_DESIGN.md`/`ARCHITECTURE.md`/
`ROADMAP.md`, `README.md`, `CLAUDE.md`, and code comments stay English-only, since this repo (like
`bitzgroup/SpriteKit` and `bitzgroup/GameplayKit`) is public OSS. Follow the device's system locale
automatically (`ja*` → Japanese, everything else → the English base); the MVP has no in-app
language switcher.

No string is ever hardcoded into a scene — every label goes through the platform's own
localization lookup (see `docs/ARCHITECTURE.md` for the exact mechanism on each platform), keyed
identically on both platforms so the string table itself doubles as a parity artifact. The full
key list, English source strings (`%d` = a formatted integer placeholder), and Japanese
translations:

| Key | English (`en`) | Japanese (`ja`) |
|---|---|---|
| `menu_title` | Tic-Tac-Toe | 三目並べ |
| `difficulty_easy` | Easy | やさしい |
| `difficulty_normal` | Normal | ふつう |
| `difficulty_hard` | Hard | むずかしい |
| `status_your_turn` | Your turn (%@) | あなたの番（%@） |
| `status_cpu_thinking` | CPU thinking… | CPU思考中… |
| `status_you_win` | You win! | あなたの勝ち！ |
| `status_cpu_wins` | CPU wins | CPUの勝ち |
| `status_draw` | Draw | 引き分け |
| `score_row` | X: %d  O: %d  Draws: %d | X: %d  O: %d  引き分け: %d |
| `new_game` | New Game | もう一度 |

`X`/`O` themselves (the marks and the `%@` fill-in for `status_your_turn`) are never translated —
they're the universal notation the game is named after on both platforms, not prose.

## Parity checklist

Used in Phase 4 of `docs/ROADMAP.md` to sign off that the two apps match. For a given
difficulty and a given sequence of taps on both apps:

- [ ] Board state after each move is identical on both apps.
- [ ] Win/loss/draw is declared on the same move on both apps.
- [ ] Hard-mode AI never loses on either app, and picks the same move as the other app whenever the
      position has a strictly-best move (see the tie-break note above for the one documented
      exception).
- [ ] Easy-mode AI only ever plays legal moves on both apps (it is expected, not a bug, that its
      exact move differs run to run and app to app — it's unseeded).
- [ ] Turn/status label text and score row match at every step.
- [ ] Visual layout (grid size/position, mark shape/size/line-width, colors) matches at the same
      device pixel density class (see `docs/ARCHITECTURE.md` for how screen size is handled on
      each platform).
- [ ] `MenuScene` → `GameScene` and New Game transitions both play the same `SKTransition` on both
      apps.
- [ ] Every placed mark is a `GKEntity` with a `GKSKNodeComponent` wrapping its node, added to the
      scene's `GKScene.entities` on both apps, and New Game leaves no stale entities behind.
- [ ] Every string in the [Localization](#localization) table renders correctly, on both apps, in
      both `en` and `ja` (switch the device/simulator system language, not an in-app switcher).
