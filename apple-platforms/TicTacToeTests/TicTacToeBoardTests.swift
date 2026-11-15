import XCTest
@testable import TicTacToe

/// Direct unit tests against `TicTacToeBoard` — pure rules, no GameplayKit fixture needed. See
/// `docs/ROADMAP.md` Phase 1.
final class TicTacToeBoardTests: XCTestCase {
    private static let winningLines: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6],
    ]

    // MARK: - Win detection (all 8 lines)

    func testXWinsEveryLine() {
        for line in Self.winningLines {
            var board = TicTacToeBoard()
            let others = (0..<9).filter { !line.contains($0) }
            for i in 0..<3 {
                board.applyMove(at: line[i]) // X
                if i < 2 { board.applyMove(at: others[i]) } // O, between X's moves only
            }
            XCTAssertEqual(board.winner, .x, "expected X to win via line \(line)")
            XCTAssertTrue(board.isWin(for: .x))
            XCTAssertTrue(board.isLoss(for: .o))
            XCTAssertFalse(board.isWin(for: .o))
            XCTAssertFalse(board.isLoss(for: .x))
            XCTAssertTrue(board.isGameOver)
        }
    }

    func testOWinsALine() {
        // X: 0, 1, 6 (no line); O: 3, 4, 5 (middle row) — O wins on its 3rd move.
        var board = TicTacToeBoard()
        for cellIndex in [0, 3, 1, 4, 6, 5] {
            board.applyMove(at: cellIndex)
        }
        XCTAssertEqual(board.winner, .o)
        XCTAssertTrue(board.isWin(for: .o))
        XCTAssertTrue(board.isLoss(for: .x))
        XCTAssertTrue(board.isGameOver)
    }

    // MARK: - Draw detection

    func testDraw() {
        var board = TicTacToeBoard()
        // X: 0,2,3,7,8  O: 1,4,5,6 — full board, no winning line.
        for cellIndex in [0, 1, 2, 4, 3, 5, 7, 6, 8] {
            board.applyMove(at: cellIndex)
        }
        XCTAssertNil(board.winner)
        XCTAssertTrue(board.isGameOver)
        XCTAssertTrue(board.legalMoves.isEmpty)
        XCTAssertFalse(board.isWin(for: .x))
        XCTAssertFalse(board.isWin(for: .o))
        XCTAssertFalse(board.isLoss(for: .x))
        XCTAssertFalse(board.isLoss(for: .o))
    }

    // MARK: - Legal-move generation

    func testLegalMovesStartFull() {
        let board = TicTacToeBoard()
        XCTAssertEqual(board.legalMoves, Array(0..<9))
    }

    func testLegalMovesExcludeOccupiedCellsInAscendingOrder() {
        var board = TicTacToeBoard()
        board.applyMove(at: 4)
        board.applyMove(at: 0)
        XCTAssertEqual(board.legalMoves, [1, 2, 3, 5, 6, 7, 8])
    }

    func testLegalMovesEmptyOnceWon() {
        var board = TicTacToeBoard()
        for cellIndex in [0, 3, 1, 4, 2] { // X: 0,1,2 (top row); O: 3,4
            board.applyMove(at: cellIndex)
        }
        XCTAssertEqual(board.winner, .x)
        XCTAssertTrue(board.legalMoves.isEmpty)
    }

    func testActiveMarkAlternatesStartingWithX() {
        var board = TicTacToeBoard()
        XCTAssertEqual(board.activeMark, .x)
        board.applyMove(at: 0)
        XCTAssertEqual(board.activeMark, .o)
        board.applyMove(at: 1)
        XCTAssertEqual(board.activeMark, .x)
    }

    // MARK: - unapplyMove (see docs/GAME_DESIGN.md's "Game model" section)

    func testUnapplyMoveReversesApplyMove() {
        var board = TicTacToeBoard()
        board.applyMove(at: 4)
        board.unapplyMove(at: 4)
        XCTAssertEqual(board.legalMoves, Array(0..<9))
        XCTAssertEqual(board.activeMark, .x)
    }
}
