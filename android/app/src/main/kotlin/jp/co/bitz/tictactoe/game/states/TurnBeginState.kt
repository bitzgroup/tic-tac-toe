package jp.co.bitz.tictactoe.game.states

import jp.co.bitz.gameplaykit.GKState
import jp.co.bitz.tictactoe.game.TicTacToeMatch
import jp.co.bitz.tictactoe.game.TicTacToePlayer
import kotlin.reflect.KClass

/**
 * Routes to [HumanTurnState] or [AITurnState] depending on whose turn it is. See
 * docs/GAME_DESIGN.md's "Turn flow" section.
 */
public class TurnBeginState(
    private val match: TicTacToeMatch,
) : GKState() {
    override fun didEnter(previousState: GKState?) {
        val activePlayer = match.gameModel.activePlayer as? TicTacToePlayer ?: return
        if (activePlayer.mark == match.humanMark) {
            stateMachine?.enter<HumanTurnState>()
        } else {
            stateMachine?.enter<AITurnState>()
        }
    }

    override fun isValidNextState(stateClass: KClass<out GKState>): Boolean =
        stateClass == HumanTurnState::class || stateClass == AITurnState::class
}
