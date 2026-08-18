package jp.co.bitz.tictactoe.game

import jp.co.bitz.gameplaykit.GKMinmaxStrategist
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Cross-platform move parity for Hard mode — see docs/GAME_DESIGN.md's "Parity checklist": "Hard-
 * mode AI ... picks the same move as the other app whenever the position has a strictly-best
 * move." `TicTacToeHardStrategistTest` already proves Hard never loses on this platform alone;
 * this test additionally pins `GKMinmaxStrategist.bestMoveForActivePlayer()`'s exact choice at
 * hand-picked positions that are provably *unambiguous* under this app's undiscounted
 * `score(for:)` (`+1`/`-1`/`0`, no reward for winning sooner — see docs/GAME_DESIGN.md's "Game
 * model" section):
 *
 * - The opening move from an empty board, and the reply to a corner opening — both spelled out by
 *   name in docs/GAME_DESIGN.md's tie-break note as the one documented case where the fixed
 *   ascending-cell-index tie-break (not an unambiguous score) is what makes the two platforms
 *   agree, so asserting it here is exactly what that note promises.
 * - Two "block the only threat or lose" positions (one with Hard to move, one with Hard's opponent
 *   about to move so Hard must be the one under threat) — here the blocking cell is the *only*
 *   legal move that isn't an outright forced loss, so it's unambiguously correct under any
 *   scoring, not merely a tie-break artifact.
 *
 * **Why this test doesn't attempt full-game move-trace equality:** an earlier version of this test
 * compared entire played-out game traces and found iOS and Android *diverging* partway through a
 * game — investigation showed this wasn't an OSS/Apple discrepancy at all: once Hard has a forced
 * win available, `score(for:)`'s lack of a depth discount means every move that *also* leads to a
 * guaranteed eventual win (e.g. building a fork instead of taking an immediate three-in-a-row)
 * scores identically to the immediate win, so the position is a genuine tie, not a
 * "strictly-best-move" position — outside what the parity checklist promises will match. Hence
 * this test sticks to hand-verified unambiguous positions instead. See docs/ROADMAP.md Phase 4 for
 * where this finding is recorded. The identical positions/expectations below are also asserted by
 * `TicTacToeHardStrategistParityTests` on iOS.
 */
class TicTacToeHardStrategistParityTest {
    @Test
    fun `opening move from empty board`() {
        assertEquals(0, bestMove(TicTacToeBoard()))
    }

    @Test
    fun `reply to a corner opening`() {
        assertEquals(4, bestMove(boardApplying(0)))
    }

    /**
     * Hard (X) to move; O already threatens row [0, 1, 2]. Blocking at 2 is the only move that
     * isn't an immediate forced loss — X's own marks (4, 8) share no line, so X has no counter-win
     * to race O with.
     */
    @Test
    fun `blocks the only threat when Hard is about to move`() {
        assertEquals(2, bestMove(boardApplying(4, 0, 8, 1)))
    }

    /**
     * O (Hard) to move; X already threatens row [0, 1, 2]. Same shape as the test above, mirrored
     * to the other seat.
     */
    @Test
    fun `blocks the only threat when Hard is the opponent`() {
        assertEquals(2, bestMove(boardApplying(0, 4, 1)))
    }

    private fun bestMove(board: TicTacToeBoard): Int? {
        val gameModel = TicTacToeGameModel(board)
        val strategist =
            GKMinmaxStrategist().apply {
                maxLookAheadDepth = 9
                this.gameModel = gameModel
            }
        return (strategist.bestMoveForActivePlayer() as? TicTacToeMove)?.cellIndex
    }

    private fun boardApplying(vararg moves: Int): TicTacToeBoard {
        val board = TicTacToeBoard()
        moves.forEach { board.applyMove(it) }
        return board
    }
}
