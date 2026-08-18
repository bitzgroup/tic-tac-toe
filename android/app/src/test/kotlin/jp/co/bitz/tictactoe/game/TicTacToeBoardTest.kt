package jp.co.bitz.tictactoe.game

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Direct unit tests against [TicTacToeBoard] — pure rules, no GameplayKit fixture needed. See
 * docs/ROADMAP.md Phase 1.
 */
class TicTacToeBoardTest {
    // Win detection (all 8 lines)

    @Test
    fun `X wins every line`() {
        for (line in WINNING_LINES) {
            val board = TicTacToeBoard()
            val others = (0 until 9).filterNot { it in line }
            for (i in 0 until 3) {
                board.applyMove(line[i]) // X
                if (i < 2) board.applyMove(others[i]) // O, between X's moves only
            }
            assertEquals(Mark.X, board.winner, "expected X to win via line $line")
            assertTrue(board.isWin(Mark.X))
            assertTrue(board.isLoss(Mark.O))
            assertFalse(board.isWin(Mark.O))
            assertFalse(board.isLoss(Mark.X))
            assertTrue(board.isGameOver)
        }
    }

    @Test
    fun `O wins a line`() {
        // X: 0, 1, 6 (no line); O: 3, 4, 5 (middle row) — O wins on its 3rd move.
        val board = TicTacToeBoard()
        for (cellIndex in listOf(0, 3, 1, 4, 6, 5)) {
            board.applyMove(cellIndex)
        }
        assertEquals(Mark.O, board.winner)
        assertTrue(board.isWin(Mark.O))
        assertTrue(board.isLoss(Mark.X))
        assertTrue(board.isGameOver)
    }

    // Draw detection

    @Test
    fun `draw`() {
        val board = TicTacToeBoard()
        // X: 0,2,3,7,8  O: 1,4,5,6 — full board, no winning line.
        for (cellIndex in listOf(0, 1, 2, 4, 3, 5, 7, 6, 8)) {
            board.applyMove(cellIndex)
        }
        assertNull(board.winner)
        assertTrue(board.isGameOver)
        assertTrue(board.legalMoves.isEmpty())
        assertFalse(board.isWin(Mark.X))
        assertFalse(board.isWin(Mark.O))
        assertFalse(board.isLoss(Mark.X))
        assertFalse(board.isLoss(Mark.O))
    }

    // Legal-move generation

    @Test
    fun `legal moves start full`() {
        val board = TicTacToeBoard()
        assertEquals((0 until 9).toList(), board.legalMoves)
    }

    @Test
    fun `legal moves exclude occupied cells in ascending order`() {
        val board = TicTacToeBoard()
        board.applyMove(4)
        board.applyMove(0)
        assertEquals(listOf(1, 2, 3, 5, 6, 7, 8), board.legalMoves)
    }

    @Test
    fun `legal moves empty once won`() {
        val board = TicTacToeBoard()
        for (cellIndex in listOf(0, 3, 1, 4, 2)) { // X: 0,1,2 (top row); O: 3,4
            board.applyMove(cellIndex)
        }
        assertEquals(Mark.X, board.winner)
        assertTrue(board.legalMoves.isEmpty())
    }

    @Test
    fun `active mark alternates starting with X`() {
        val board = TicTacToeBoard()
        assertEquals(Mark.X, board.activeMark)
        board.applyMove(0)
        assertEquals(Mark.O, board.activeMark)
        board.applyMove(1)
        assertEquals(Mark.X, board.activeMark)
    }

    // unapplyMove (see docs/GAME_DESIGN.md's "Game model" section)

    @Test
    fun `unapplyMove reverses applyMove`() {
        val board = TicTacToeBoard()
        board.applyMove(4)
        board.unapplyMove(4)
        assertEquals((0 until 9).toList(), board.legalMoves)
        assertEquals(Mark.X, board.activeMark)
    }

    private companion object {
        val WINNING_LINES =
            listOf(
                listOf(0, 1, 2),
                listOf(3, 4, 5),
                listOf(6, 7, 8),
                listOf(0, 3, 6),
                listOf(1, 4, 7),
                listOf(2, 5, 8),
                listOf(0, 4, 8),
                listOf(2, 4, 6),
            )
    }
}
