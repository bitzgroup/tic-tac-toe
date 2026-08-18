package jp.co.bitz.tictactoe.game.states

import jp.co.bitz.gameplaykit.GKState
import jp.co.bitz.tictactoe.game.TicTacToeMatch
import jp.co.bitz.tictactoe.game.TicTacToeMove
import kotlin.reflect.KClass

/**
 * Waits for the SpriteKit layer (Phase 2) to report a tap via [applyHumanMove]. See
 * docs/GAME_DESIGN.md's "Turn flow" section.
 */
public class HumanTurnState(
    private val match: TicTacToeMatch,
) : GKState() {
    /**
     * Applies a tap at [cellIndex] if it's a legal move for the active player, advancing to
     * [TurnEndState]. Returns whether the move was applied.
     */
    public fun applyHumanMove(cellIndex: Int): Boolean {
        val move =
            match.gameModel.activePlayer
                ?.let { match.gameModel.gameModelUpdates(it) }
                ?.filterIsInstance<TicTacToeMove>()
                ?.firstOrNull { it.cellIndex == cellIndex }
        return if (move != null) {
            match.gameModel.apply(move)
            stateMachine?.enter<TurnEndState>() ?: false
        } else {
            false
        }
    }

    override fun isValidNextState(stateClass: KClass<out GKState>): Boolean = stateClass == TurnEndState::class
}
