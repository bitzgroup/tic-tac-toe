package jp.co.bitz.tictactoe.game.states

import jp.co.bitz.gameplaykit.GKState
import jp.co.bitz.tictactoe.game.TicTacToeMatch
import kotlin.reflect.KClass

/**
 * Checks whether the game just ended; routes to [GameOverState] or back to [TurnBeginState] for
 * the next turn. See docs/GAME_DESIGN.md's "Turn flow" section.
 */
public class TurnEndState(
    private val match: TicTacToeMatch,
) : GKState() {
    override fun didEnter(previousState: GKState?) {
        if (match.gameModel.board.isGameOver) {
            stateMachine?.enter<GameOverState>()
        } else {
            stateMachine?.enter<TurnBeginState>()
        }
    }

    override fun isValidNextState(stateClass: KClass<out GKState>): Boolean =
        stateClass == GameOverState::class || stateClass == TurnBeginState::class
}
