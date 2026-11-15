import GameplayKit
import XCTest
@testable import TicTacToe

/// Drives `GameScene` through complete games via `CellNode.touchesBegan` directly (no OS-level
/// touch simulation available in a unit test target) — exercises the real production path
/// (`HumanTurnState.applyHumanMove` → `GKStateMachine` cascade → `AITurnState`) end to end at
/// every difficulty. See `docs/ROADMAP.md` Phase 3's "playable start-to-finish" item.
///
/// Note: `AITurnState`'s move is applied to `match` synchronously (Phase 1), but `GameScene`
/// defers *revealing* it via `SKAction.wait` (Phase 2) — a real `SKView` frame loop drives that,
/// which this headless test has none of. So a game that ends on the AI's move never fires
/// `handleGameOver()`/updates `statusLabel` within this test, even though `match`'s model state is
/// already correctly terminal — see the class doc above. That visual reveal path was already
/// verified manually via simulator screenshots when Phase 2 landed; this test covers the
/// deterministic model/state-machine wiring the "playable start-to-finish" checklist item cares
/// about, at all three difficulties.
final class GameScenePlaythroughTests: XCTestCase {
    func testEveryDifficultyReachesATerminalStateStartToFinish() {
        for difficulty in [Difficulty.easy, .normal, .hard] {
            let scene = GameScene(size: CGSize(width: 1080, height: 1920), difficulty: difficulty, humanMark: .x)

            // Synchronous, regardless of the coin toss or any deferred visual reveal.
            XCTAssertFalse(scene.statusLabel.text?.isEmpty ?? true, "\(difficulty): status label should be set from the start")

            playToCompletion(scene, difficulty: difficulty)

            XCTAssertTrue(scene.match.gameModel.board.isGameOver, "\(difficulty): game should reach a terminal state")
        }
    }

    func testNewGameAfterCompletionStartsFromACleanBoard() {
        let finished = GameScene(size: CGSize(width: 1080, height: 1920), difficulty: .hard, humanMark: .x)
        playToCompletion(finished, difficulty: .hard)
        XCTAssertTrue(finished.match.gameModel.board.isGameOver)

        // Mirrors what GameScene's own (private) startNewGame() does: construct a fresh GameScene
        // with the same difficulty/mark, carrying the running score forward.
        let newGame = GameScene(size: CGSize(width: 1080, height: 1920), difficulty: .hard, humanMark: .x)
        XCTAssertEqual(newGame.match.gameModel.board.legalMoves.count, 9, "New Game should start from an empty board")
        XCTAssertFalse(newGame.match.gameModel.board.isGameOver)
        XCTAssertTrue(newGame.gkScene.entities.isEmpty, "New Game should leave no stale mark entities behind")
    }

    /// `docs/GAME_DESIGN.md`'s "Marks as entities" section, and its parity checklist item: every
    /// placed mark is a `GKEntity` with a `GKSKNodeComponent` wrapping its node, added to the
    /// scene's `GKScene.entities` — not a bare node. See `docs/ROADMAP.md` Phase 4.
    ///
    /// Only checks *human* moves' entities: the AI's own `placeMark` call is wrapped in the
    /// deferred `SKAction` this headless test never runs (see the class doc), so an AI move's
    /// entity is never created within this test even though `handleCellTapped`'s human-side
    /// `placeMark` call — the one this test exercises — runs synchronously either way.
    func testEveryPlacedMarkIsAnEntityWithAGKSKNodeComponent() {
        let scene = GameScene(size: CGSize(width: 1080, height: 1920), difficulty: .hard, humanMark: .x)
        let humanMoveCount = playToCompletion(scene, difficulty: .hard)

        XCTAssertEqual(scene.gkScene.entities.count, humanMoveCount, "one GKEntity per placed (human) mark")
        XCTAssertGreaterThan(humanMoveCount, 0)

        for entity in scene.gkScene.entities {
            guard let nodeComponent = entity.component(ofType: GKSKNodeComponent.self) else {
                XCTFail("entity missing GKSKNodeComponent")
                continue
            }
            XCTAssertTrue(scene.children.contains(nodeComponent.node), "entity's node should be in the scene's node tree")
            XCTAssertNotNil(entity.component(ofType: TicTacToeMarkComponent.self), "entity missing TicTacToeMarkComponent")
        }
    }

    /// Repeatedly taps the first legal cell whenever it's the human's turn, until the game ends.
    /// Always terminates within 9 moves — deterministic regardless of AI difficulty/randomness.
    /// Returns the number of human moves made.
    @discardableResult
    private func playToCompletion(_ scene: GameScene, difficulty: Difficulty, file: StaticString = #filePath, line: UInt = #line) -> Int {
        var safetyCounter = 0
        while !scene.match.gameModel.board.isGameOver {
            safetyCounter += 1
            guard safetyCounter <= 9 else {
                XCTFail("\(difficulty): playthrough did not terminate within 9 human moves", file: file, line: line)
                return safetyCounter - 1
            }
            guard scene.match.stateMachine.currentState is HumanTurnState else {
                XCTFail("\(difficulty): expected HumanTurnState while the game isn't over", file: file, line: line)
                return safetyCounter - 1
            }
            guard let cellIndex = scene.match.gameModel.board.legalMoves.first else {
                XCTFail("\(difficulty): HumanTurnState but no legal moves left", file: file, line: line)
                return safetyCounter - 1
            }
            guard let cellNode = scene.children.compactMap({ $0 as? CellNode }).first(where: { $0.cellIndex == cellIndex }) else {
                XCTFail("\(difficulty): missing CellNode for cell \(cellIndex)", file: file, line: line)
                return safetyCounter - 1
            }
            cellNode.touchesBegan([], with: nil)
        }
        return safetyCounter
    }
}
