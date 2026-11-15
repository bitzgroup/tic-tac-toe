import GameplayKit
import XCTest
@testable import TicTacToe

final class TicTacToeGameModelTests: XCTestCase {
    // MARK: - copy() independence (docs/ROADMAP.md Phase 1)

    func testCopyIndependence() {
        let original = TicTacToeGameModel()
        original.apply(TicTacToeMove(cellIndex: 4)) // X

        guard let copy = original.copy() as? TicTacToeGameModel else {
            XCTFail("copy() should return a TicTacToeGameModel")
            return
        }

        // Mutating the copy must never affect the original.
        copy.apply(TicTacToeMove(cellIndex: 0)) // O, on the copy only

        XCTAssertNil(original.board.cells[0])
        XCTAssertEqual(copy.board.cells[0], .o)
        XCTAssertEqual(original.board.cells[4], .x)
        XCTAssertEqual(copy.board.cells[4], .x)
        XCTAssertEqual(original.board.activeMark, .o)
        XCTAssertEqual(copy.board.activeMark, .x)
    }

    // MARK: - gameModelUpdates(for:)

    func testGameModelUpdatesOnlyForActivePlayer() {
        let model = TicTacToeGameModel() // X to move
        XCTAssertNil(model.gameModelUpdates(for: TicTacToePlayer.o))
        XCTAssertEqual(model.gameModelUpdates(for: TicTacToePlayer.x)?.count, 9)
    }

    func testGameModelUpdatesAscendingOrder() {
        let model = TicTacToeGameModel()
        model.apply(TicTacToeMove(cellIndex: 4))
        let updates = model.gameModelUpdates(for: TicTacToePlayer.o) as? [TicTacToeMove]
        XCTAssertEqual(updates?.map(\.cellIndex), [0, 1, 2, 3, 5, 6, 7, 8])
    }

    func testGameModelUpdatesNilOnceGameOver() {
        let model = TicTacToeGameModel()
        for cellIndex in [0, 3, 1, 4, 2] { // X wins the top row
            model.apply(TicTacToeMove(cellIndex: cellIndex))
        }
        XCTAssertNil(model.gameModelUpdates(for: TicTacToePlayer.x))
        XCTAssertNil(model.gameModelUpdates(for: TicTacToePlayer.o))
    }

    // MARK: - score(for:) / isWin(for:) / isLoss(for:)

    func testScoreWinLoss() {
        let model = TicTacToeGameModel()
        for cellIndex in [0, 3, 1, 4, 2] { // X wins the top row
            model.apply(TicTacToeMove(cellIndex: cellIndex))
        }
        XCTAssertEqual(model.score(for: TicTacToePlayer.x), 1)
        XCTAssertEqual(model.score(for: TicTacToePlayer.o), -1)
        XCTAssertTrue(model.isWin(for: TicTacToePlayer.x))
        XCTAssertTrue(model.isLoss(for: TicTacToePlayer.o))
        XCTAssertFalse(model.isWin(for: TicTacToePlayer.o))
        XCTAssertFalse(model.isLoss(for: TicTacToePlayer.x))
    }

    func testScoreZeroBeforeGameEnds() {
        let model = TicTacToeGameModel()
        XCTAssertEqual(model.score(for: TicTacToePlayer.x), 0)
        XCTAssertEqual(model.score(for: TicTacToePlayer.o), 0)
    }

    // MARK: - unapplyGameModelUpdate (see docs/GAME_DESIGN.md's "Game model" section) — direct
    // regression test for this model's unapplyGameModelUpdate being a true inverse of apply,
    // matching bitzgroup/GameplayKit's Android port's own mutate-and-backtrack search test.

    func testHardSearchLeavesTheBoardExactlyAsItFoundIt() {
        let model = TicTacToeGameModel()
        model.apply(TicTacToeMove(cellIndex: 4)) // one real move played first, X at the center
        let strategist = GKMinmaxStrategist()
        strategist.maxLookAheadDepth = 9
        strategist.gameModel = model

        // bestMoveForActivePlayer only recommends a move, it never applies it — so the model
        // must come back exactly as it went in: still just the one real move played above.
        _ = strategist.bestMoveForActivePlayer()

        XCTAssertEqual(model.board.cells[4], .x)
        XCTAssertEqual(model.board.legalMoves.count, 8)
        XCTAssertEqual(model.board.activeMark, .o)
    }
}
