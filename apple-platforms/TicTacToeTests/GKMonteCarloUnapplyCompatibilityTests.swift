import GameplayKit
import XCTest
@testable import TicTacToe

/// Empirical check of whether Apple's real `GKMonteCarloStrategist` requires
/// `unapplyGameModelUpdate(_:)` to be a true inverse of `apply(_:)` (as `GKMinmaxStrategist` was
/// found to, on-device, causing a crash when it wasn't — see `TicTacToeGameModel`'s
/// `unapplyGameModelUpdate(_:)` doc comment), or whether it falls back to `copy(with:)`-based
/// backtracking per developer.apple.com's documented default for strategists in general.
///
/// `UnapplyLessGameModel` below is `TicTacToeGameModel` with `unapplyGameModelUpdate(_:)` simply
/// not overridden, leaving the `GKGameModel` protocol's default (a no-op, since it's an optional
/// Objective-C protocol method nothing here implements). If Apple's strategist falls back to
/// `copy(with:)` when `unapplyGameModelUpdate(_:)` isn't implemented, search leaves the shared
/// `gameModel` instance's board completely unchanged and returns a legal move. If it instead
/// assumes `unapply` is a true inverse regardless, backtracking silently does nothing, so
/// intermediate search states leak into the model actually returned to the caller: the board
/// should end up mutated (extra marks placed, cells that were empty pre-search no longer are) or
/// the search should crash outright (`TicTacToeBoard.applyMove(at:)`'s "already occupied"
/// precondition tripping once the leaked state collides with a still-legal-looking move).
final class GKMonteCarloUnapplyCompatibilityTests: XCTestCase {
    /// Shared call counters, threaded through every `copy(with:)`-produced instance, so a test can
    /// tell *how* the strategist explored: many `copyCount` with `unapplyCount == 0` is direct
    /// evidence of the documented copy-based fallback; growing `applyCount` with both `copyCount`
    /// and `unapplyCount` at (or near) zero would instead mean the strategist mutated the one
    /// shared model without ever backtracking it — the failure mode this test is designed to catch.
    final class Counters {
        var copyCount = 0
        var applyCount = 0
        var unapplyCount = 0
    }

    final class UnapplyLessGameModel: NSObject, GKGameModel {
        private(set) var board: TicTacToeBoard
        let counters: Counters

        init(board: TicTacToeBoard, counters: Counters = Counters()) {
            self.board = board
            self.counters = counters
        }

        var players: [GKGameModelPlayer]? { TicTacToePlayer.all }
        var activePlayer: GKGameModelPlayer? { TicTacToePlayer.player(for: board.activeMark) }

        func copy(with zone: NSZone? = nil) -> Any {
            counters.copyCount += 1
            return UnapplyLessGameModel(board: board, counters: counters)
        }

        func setGameModel(_ gameModel: GKGameModel) {
            guard let other = gameModel as? UnapplyLessGameModel else { return }
            board = other.board
        }

        func gameModelUpdates(for player: GKGameModelPlayer) -> [GKGameModelUpdate]? {
            guard let player = player as? TicTacToePlayer,
                  player.mark == board.activeMark,
                  !board.isGameOver
            else {
                return nil
            }
            return board.legalMoves.map { TicTacToeMove(cellIndex: $0) }
        }

        func apply(_ gameModelUpdate: GKGameModelUpdate) {
            counters.applyCount += 1
            guard let move = gameModelUpdate as? TicTacToeMove else { return }
            board.applyMove(at: move.cellIndex)
        }

        func score(for player: GKGameModelPlayer) -> Int {
            guard let player = player as? TicTacToePlayer else { return 0 }
            if board.isWin(for: player.mark) { return 1 }
            if board.isLoss(for: player.mark) { return -1 }
            return 0
        }

        func isWin(for player: GKGameModelPlayer) -> Bool {
            guard let player = player as? TicTacToePlayer else { return false }
            return board.isWin(for: player.mark)
        }

        func isLoss(for player: GKGameModelPlayer) -> Bool {
            guard let player = player as? TicTacToePlayer else { return false }
            return board.isLoss(for: player.mark)
        }

        // Deliberately NOT overriding `unapplyGameModelUpdate(_:)` — this is the whole point.
    }

    /// Mid-game, non-trivial branching position (`X` at 0, `O` at 4, `X` at 1 — `O` to move with
    /// 6 legal replies), so a Monte Carlo budget of hundreds of playouts forces many
    /// apply/backtrack cycles rather than terminating after one or two moves.
    func testMonteCarloStrategistLeavesModelUnchangedWithoutUnapply() {
        var board = TicTacToeBoard()
        for cellIndex in [0, 4, 1] { board.applyMove(at: cellIndex) }
        let model = UnapplyLessGameModel(board: board)

        let strategist = GKMonteCarloStrategist()
        strategist.budget = 500
        strategist.explorationParameter = 1
        strategist.gameModel = model

        let beforeCells = model.board.cells
        let beforeActiveMark = model.board.activeMark

        let move = strategist.bestMoveForActivePlayer() as? TicTacToeMove

        XCTAssertEqual(
            model.board.cells, beforeCells,
            "gameModel board mutated by search — GKMonteCarloStrategist did not restore state " +
                "after backtracking without a real unapplyGameModelUpdate(_:)"
        )
        XCTAssertEqual(model.board.activeMark, beforeActiveMark)
        XCTAssertNotNil(move, "strategist returned no move at all")
        if let move {
            XCTAssertTrue(
                beforeCells[move.cellIndex] == nil,
                "strategist returned a move (\(move.cellIndex)) for a cell that was already " +
                    "occupied on the pre-search board — search state leaked into the result"
            )
        }

        // Mechanism check: real copy-based fallback should mean many `copy(with:)` calls (one per
        // explored node) and zero calls to `unapplyGameModelUpdate(_:)` (nothing here implements
        // it, so it's uncallable by construction — this just documents the count is exactly 0).
        XCTAssertGreaterThan(
            model.counters.copyCount, 0,
            "expected GKMonteCarloStrategist to call copy(with:) to branch search state; " +
                "it called it \(model.counters.copyCount) times"
        )
        XCTAssertEqual(model.counters.unapplyCount, 0)
        print(
            "[GKMonteCarloUnapplyCompatibilityTests] copyCount=\(model.counters.copyCount) " +
                "applyCount=\(model.counters.applyCount) unapplyCount=\(model.counters.unapplyCount)"
        )
    }

    /// Stress variant: from the empty board (maximum branching — 9 legal opening replies) with a
    /// budget an order of magnitude larger, repeated over many trials, to rule out the clean result
    /// above being a fluke of Monte Carlo's own randomness rather than the strategist's actual
    /// backtracking mechanism.
    func testMonteCarloStrategistStaysCleanAcrossManyLargeBudgetTrials() {
        for trial in 0 ..< 20 {
            var board = TicTacToeBoard()
            // Vary the starting position across trials so different subtrees get explored.
            let opening = [[], [0], [4], [0, 4], [0, 4, 1], [4, 0, 8, 1]][trial % 6]
            for cellIndex in opening { board.applyMove(at: cellIndex) }
            let model = UnapplyLessGameModel(board: board)

            let strategist = GKMonteCarloStrategist()
            strategist.budget = 3000
            strategist.explorationParameter = 1
            strategist.gameModel = model

            let beforeCells = model.board.cells
            let beforeActiveMark = model.board.activeMark

            let move = strategist.bestMoveForActivePlayer() as? TicTacToeMove

            XCTAssertEqual(model.board.cells, beforeCells, "trial \(trial), opening \(opening)")
            XCTAssertEqual(model.board.activeMark, beforeActiveMark, "trial \(trial)")
            if let move {
                XCTAssertTrue(beforeCells[move.cellIndex] == nil, "trial \(trial)")
            }
            XCTAssertEqual(model.counters.unapplyCount, 0)
        }
    }

    /// Same check repeated from a position one ply from game-over (`X`: 0,1 — one more `X` move at
    /// `2` wins), so the search space includes terminal nodes and `unapplyMove`'s precondition
    /// would be hit almost immediately if backtracking silently no-ops.
    func testMonteCarloStrategistLeavesModelUnchangedNearGameEnd() {
        var board = TicTacToeBoard()
        for cellIndex in [0, 3, 1] { board.applyMove(at: cellIndex) }
        let model = UnapplyLessGameModel(board: board)

        let strategist = GKMonteCarloStrategist()
        strategist.budget = 500
        strategist.explorationParameter = 1
        strategist.gameModel = model

        let beforeCells = model.board.cells
        let beforeActiveMark = model.board.activeMark

        _ = strategist.bestMoveForActivePlayer()

        XCTAssertEqual(model.board.cells, beforeCells)
        XCTAssertEqual(model.board.activeMark, beforeActiveMark)
    }
}
