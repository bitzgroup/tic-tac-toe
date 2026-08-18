package jp.co.bitz.tictactoe.game

import jp.co.bitz.gameplaykit.GKGameModel
import jp.co.bitz.gameplaykit.GKGameModelPlayer
import jp.co.bitz.gameplaykit.GKGameModelUpdate

/**
 * Conforms [TicTacToeBoard] to [GKGameModel] by wrapping it — see docs/GAME_DESIGN.md's "Game
 * model" section for why this is a separate type from the board's own rules.
 *
 * `apply`/`unapplyGameModelUpdate` are true inverses of each other, matching `TicTacToeGameModel`
 * on iOS exactly: `bitzgroup/GameplayKit`'s `GKMinmaxStrategist`/`GKMonteCarloStrategist` mutate
 * one shared model in place during search — `apply` a candidate move, recurse/roll out,
 * `unapplyGameModelUpdate` it back off — the same strategy Apple's own `GKMinmaxStrategist`
 * documents itself using. See `GKGameModel`'s own KDoc in that library.
 */
public class TicTacToeGameModel(
    public var board: TicTacToeBoard = TicTacToeBoard(),
) : GKGameModel {
    override val players: List<GKGameModelPlayer> = TicTacToePlayer.all

    override val activePlayer: GKGameModelPlayer
        get() = TicTacToePlayer.player(board.activeMark)

    override fun copy(): GKGameModel = TicTacToeGameModel(board.copy())

    override fun setGameModel(gameModel: GKGameModel) {
        val other = gameModel as? TicTacToeGameModel ?: return
        board = other.board
    }

    override fun gameModelUpdates(player: GKGameModelPlayer): List<GKGameModelUpdate>? {
        val ticTacToePlayer = player as? TicTacToePlayer
        val isPlayersTurn = ticTacToePlayer != null && !board.isGameOver && ticTacToePlayer.mark == board.activeMark
        return if (isPlayersTurn) board.legalMoves.map { TicTacToeMove(it) } else null
    }

    override fun apply(gameModelUpdate: GKGameModelUpdate) {
        val move = gameModelUpdate as? TicTacToeMove ?: return
        board.applyMove(move.cellIndex)
    }

    override fun score(player: GKGameModelPlayer): Int {
        val ticTacToePlayer = player as? TicTacToePlayer ?: return 0
        return when {
            board.isWin(ticTacToePlayer.mark) -> 1
            board.isLoss(ticTacToePlayer.mark) -> -1
            else -> 0
        }
    }

    override fun isWin(player: GKGameModelPlayer): Boolean {
        val ticTacToePlayer = player as? TicTacToePlayer ?: return false
        return board.isWin(ticTacToePlayer.mark)
    }

    override fun isLoss(player: GKGameModelPlayer): Boolean {
        val ticTacToePlayer = player as? TicTacToePlayer ?: return false
        return board.isLoss(ticTacToePlayer.mark)
    }

    override fun unapplyGameModelUpdate(gameModelUpdate: GKGameModelUpdate) {
        val move = gameModelUpdate as? TicTacToeMove ?: return
        board.unapplyMove(move.cellIndex)
    }
}
