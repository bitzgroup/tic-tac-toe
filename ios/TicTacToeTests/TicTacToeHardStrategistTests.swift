import GameplayKit
import XCTest
@testable import TicTacToe

/// Hard mode (`GKMinmaxStrategist`, `maxLookAheadDepth = 9`) must never lose, regardless of seat
/// or opponent — Tic-Tac-Toe is a solved game. Run against a representative set of opening/
/// mid-game board states, playing full games to completion. See `docs/ROADMAP.md` Phase 1.
final class TicTacToeHardStrategistTests: XCTestCase {
    /// Deterministic stand-ins for "some legal-but-not-necessarily-optimal opponent" — minmax
    /// played correctly can't lose to *any* legal opponent, so exercising a couple of simple,
    /// reproducible ones (rather than a random source) is sufficient and keeps this test
    /// deterministic.
    private enum OpponentStrategy: CaseIterable {
        case first, last

        func chooseMove(from updates: [TicTacToeMove]) -> TicTacToeMove {
            switch self {
            case .first: return updates.first!
            case .last: return updates.last!
            }
        }
    }

    // Every board here is chosen to be a *sound* position for whichever side is about to move —
    // i.e. not already a forced loss baked in by a bad earlier move — since minmax only
    // guarantees never losing given correct play from that point on, not rescuing an already-lost
    // position. `[X: 0, O: 1, X: 3]` was tried here and dropped: O's reply to a corner opening
    // must be the center to stay safe, so `1` (an edge) leaves O already lost to a fork on `4`
    // regardless of what O does next — a real, useful way this test caught a genuine minmax bug
    // (see the `unapplyGameModelUpdate` fix this test suite drove), but the wrong shape for *this*
    // never-loses assertion once that bug was fixed.
    private static let startingBoards: [TicTacToeBoard] = [
        TicTacToeBoard(),
        boardApplying([0]), // X took a corner; O (Hard) makes the critical first reply itself
        boardApplying([4]), // X took the center; likewise
        boardApplying([0, 4]), // X corner, O center — the sound reply, drawn with correct play
    ]

    func testHardStrategistNeverLoses() {
        for startingBoard in Self.startingBoards {
            for hardMark in [Mark.x, Mark.o] {
                for opponent in OpponentStrategy.allCases {
                    playFullGame(startingBoard: startingBoard, hardMark: hardMark, opponent: opponent)
                }
            }
        }
    }

    private func playFullGame(startingBoard: TicTacToeBoard, hardMark: Mark, opponent: OpponentStrategy) {
        let gameModel = TicTacToeGameModel(board: startingBoard)
        let strategist = GKMinmaxStrategist()
        strategist.maxLookAheadDepth = 9
        strategist.gameModel = gameModel

        while !gameModel.board.isGameOver {
            let activeMark = gameModel.board.activeMark
            let activePlayer = TicTacToePlayer.player(for: activeMark)
            let move: TicTacToeMove
            if activeMark == hardMark {
                guard let best = strategist.bestMoveForActivePlayer() as? TicTacToeMove else {
                    XCTFail("Hard strategist returned no move on a non-terminal board")
                    return
                }
                move = best
            } else {
                guard let updates = gameModel.gameModelUpdates(for: activePlayer) as? [TicTacToeMove] else {
                    XCTFail("expected a legal move for the opponent")
                    return
                }
                move = opponent.chooseMove(from: updates)
            }
            gameModel.apply(move)
        }

        XCTAssertFalse(
            gameModel.isLoss(for: TicTacToePlayer.player(for: hardMark)),
            "Hard strategist (as \(hardMark), vs. \(opponent) opponent) lost from starting board \(startingBoard.cells)"
        )
    }

    private static func boardApplying(_ moves: [Int]) -> TicTacToeBoard {
        var board = TicTacToeBoard()
        for cellIndex in moves { board.applyMove(at: cellIndex) }
        return board
    }
}
