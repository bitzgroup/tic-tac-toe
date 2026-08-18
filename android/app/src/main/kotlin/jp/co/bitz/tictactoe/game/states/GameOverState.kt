package jp.co.bitz.tictactoe.game.states

import jp.co.bitz.gameplaykit.GKState
import kotlin.reflect.KClass

/**
 * Terminal state for one match — see docs/GAME_DESIGN.md's "Turn flow" section: a new game is a
 * new [jp.co.bitz.tictactoe.game.TicTacToeMatch], never a transition back out of this state.
 */
public class GameOverState : GKState() {
    override fun isValidNextState(stateClass: KClass<out GKState>): Boolean = false
}
