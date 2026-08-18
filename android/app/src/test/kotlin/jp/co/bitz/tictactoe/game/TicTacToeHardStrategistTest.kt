package jp.co.bitz.tictactoe.game

import jp.co.bitz.gameplaykit.GKMinmaxStrategist
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.fail

/**
 * Hard mode (`GKMinmaxStrategist`, `maxLookAheadDepth = 9`) must never lose, regardless of seat or
 * opponent — Tic-Tac-Toe is a solved game. Run against a representative set of opening/mid-game
 * board states, playing full games to completion. See docs/ROADMAP.md Phase 1.
 */
class TicTacToeHardStrategistTest {
    /**
     * Deterministic stand-ins for "some legal-but-not-necessarily-optimal opponent" — minmax
     * played correctly can't lose to *any* legal opponent, so exercising a couple of simple,
     * reproducible ones (rather than a random source) is sufficient and keeps this test
     * deterministic.
     */
    private enum class OpponentStrategy {
        FIRST,
        LAST,
        ;

        fun chooseMove(updates: List<TicTacToeMove>): TicTacToeMove =
            when (this) {
                FIRST -> updates.first()
                LAST -> updates.last()
            }
    }

    @Test
    fun `Hard strategist never loses`() {
        for (makeStartingBoard in startingBoards()) {
            for (hardMark in listOf(Mark.X, Mark.O)) {
                for (opponent in OpponentStrategy.entries) {
                    playFullGame(makeStartingBoard(), hardMark, opponent)
                }
            }
        }
    }

    private fun playFullGame(
        startingBoard: TicTacToeBoard,
        hardMark: Mark,
        opponent: OpponentStrategy,
    ) {
        val gameModel = TicTacToeGameModel(startingBoard)
        val strategist =
            GKMinmaxStrategist().apply {
                maxLookAheadDepth = 9
                this.gameModel = gameModel
            }

        while (!gameModel.board.isGameOver) {
            val activeMark = gameModel.board.activeMark
            val activePlayer = TicTacToePlayer.player(activeMark)
            val move: TicTacToeMove =
                if (activeMark == hardMark) {
                    strategist.bestMoveForActivePlayer() as? TicTacToeMove
                        ?: fail("Hard strategist returned no move on a non-terminal board")
                } else {
                    val updates =
                        gameModel.gameModelUpdates(activePlayer)?.filterIsInstance<TicTacToeMove>()
                            ?: fail("expected a legal move for the opponent")
                    opponent.chooseMove(updates)
                }
            gameModel.apply(move)
        }

        assertFalse(
            gameModel.isLoss(TicTacToePlayer.player(hardMark)),
            "Hard strategist (as $hardMark, vs. $opponent opponent) lost from starting board ${startingBoard.cells}",
        )
    }

    // Every board here is chosen to be a *sound* position for whichever side is about to move —
    // i.e. not already a forced loss baked in by a bad earlier move — since minmax only
    // guarantees never losing given correct play from that point on, not rescuing an
    // already-lost position. `[X: 0, O: 1, X: 3]` was tried on iOS and dropped there for the same
    // reason: O's reply to a corner opening must be the center to stay safe, so `1` (an edge)
    // leaves O already lost to a fork on `4` regardless of what O does next. See
    // docs/ARCHITECTURE.md's "Finding OSS/Apple discrepancies" section for what that iOS-side
    // test run actually caught (a real `unapplyGameModelUpdate` bug, not this board-choice issue).
    private fun startingBoards(): List<() -> TicTacToeBoard> =
        listOf(
            { TicTacToeBoard() },
            // X took a corner; O (Hard) makes the critical first reply itself.
            { boardApplying(0) },
            // X took the center; likewise.
            { boardApplying(4) },
            // X corner, O center — the sound reply, drawn with correct play.
            { boardApplying(0, 4) },
        )

    private fun boardApplying(vararg moves: Int): TicTacToeBoard {
        val board = TicTacToeBoard()
        moves.forEach { board.applyMove(it) }
        return board
    }
}
