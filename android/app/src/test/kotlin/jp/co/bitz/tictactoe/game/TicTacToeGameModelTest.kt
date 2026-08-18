package jp.co.bitz.tictactoe.game

import jp.co.bitz.gameplaykit.GKMinmaxStrategist
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class TicTacToeGameModelTest {
    // copy() independence (docs/ROADMAP.md Phase 1)

    @Test
    fun `copy is independent of the original`() {
        val original = TicTacToeGameModel()
        original.apply(TicTacToeMove(4)) // X

        val copy = original.copy() as TicTacToeGameModel

        // Mutating the copy must never affect the original.
        copy.apply(TicTacToeMove(0)) // O, on the copy only

        assertNull(original.board.cells[0])
        assertEquals(Mark.O, copy.board.cells[0])
        assertEquals(Mark.X, original.board.cells[4])
        assertEquals(Mark.X, copy.board.cells[4])
        assertEquals(Mark.O, original.board.activeMark)
        assertEquals(Mark.X, copy.board.activeMark)
    }

    // gameModelUpdates(player)

    @Test
    fun `gameModelUpdates is only for the active player`() {
        val model = TicTacToeGameModel() // X to move
        assertNull(model.gameModelUpdates(TicTacToePlayer.o))
        assertEquals(9, model.gameModelUpdates(TicTacToePlayer.x)?.size)
    }

    @Test
    fun `gameModelUpdates is in ascending cell-index order`() {
        val model = TicTacToeGameModel()
        model.apply(TicTacToeMove(4))
        val updates = model.gameModelUpdates(TicTacToePlayer.o)?.filterIsInstance<TicTacToeMove>()
        assertEquals(listOf(0, 1, 2, 3, 5, 6, 7, 8), updates?.map { it.cellIndex })
    }

    @Test
    fun `gameModelUpdates is null once the game is over`() {
        val model = TicTacToeGameModel()
        for (cellIndex in listOf(0, 3, 1, 4, 2)) { // X wins the top row
            model.apply(TicTacToeMove(cellIndex))
        }
        assertNull(model.gameModelUpdates(TicTacToePlayer.x))
        assertNull(model.gameModelUpdates(TicTacToePlayer.o))
    }

    // score(player) / isWin(player) / isLoss(player)

    @Test
    fun `score reflects win and loss`() {
        val model = TicTacToeGameModel()
        for (cellIndex in listOf(0, 3, 1, 4, 2)) { // X wins the top row
            model.apply(TicTacToeMove(cellIndex))
        }
        assertEquals(1, model.score(TicTacToePlayer.x))
        assertEquals(-1, model.score(TicTacToePlayer.o))
        assertTrue(model.isWin(TicTacToePlayer.x))
        assertTrue(model.isLoss(TicTacToePlayer.o))
    }

    @Test
    fun `score is zero before the game ends`() {
        val model = TicTacToeGameModel()
        assertEquals(0, model.score(TicTacToePlayer.x))
        assertEquals(0, model.score(TicTacToePlayer.o))
    }

    // unapplyGameModelUpdate (see docs/GAME_DESIGN.md's "Game model" section) — direct regression
    // test for `bitzgroup/GameplayKit`'s mutate-and-backtrack search: fails if this model's
    // unapplyGameModelUpdate isn't a true inverse of apply.
    @Test
    fun `Hard search leaves the board exactly as it found it`() {
        val model = TicTacToeGameModel()
        model.apply(TicTacToeMove(4)) // one real move played first, X at the center
        val strategist =
            GKMinmaxStrategist().apply {
                maxLookAheadDepth = 9
                gameModel = model
            }

        // bestMoveForActivePlayer only recommends a move, it never applies it — so the model
        // must come back exactly as it went in: still just the one real move played above.
        strategist.bestMoveForActivePlayer()

        assertEquals(Mark.X, model.board.cells[4])
        assertEquals(8, model.board.legalMoves.size)
        assertEquals(Mark.O, model.board.activeMark)
    }
}
