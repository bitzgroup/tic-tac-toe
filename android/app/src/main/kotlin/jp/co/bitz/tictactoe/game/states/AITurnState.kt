package jp.co.bitz.tictactoe.game.states

import jp.co.bitz.gameplaykit.GKRandomDistribution
import jp.co.bitz.gameplaykit.GKState
import jp.co.bitz.tictactoe.game.TicTacToeMatch
import jp.co.bitz.tictactoe.game.TicTacToeMove
import kotlin.reflect.KClass

/**
 * Asks the difficulty-appropriate strategist (or, on Easy, [GKRandomDistribution]) for a move and
 * applies it. See docs/GAME_DESIGN.md's "AI difficulty → GameplayKit strategist" and "Turn flow"
 * sections. No artificial delay here — the visible "CPU thinking…" pause is a SpriteKit concern
 * (Phase 2).
 */
public class AITurnState(
    private val match: TicTacToeMatch,
) : GKState() {
    override fun didEnter(previousState: GKState?) {
        val move = bestMove() ?: return
        match.gameModel.apply(move)
        stateMachine?.enter<TurnEndState>()
    }

    private fun bestMove(): TicTacToeMove? {
        val strategist = match.strategist
        if (strategist != null) return strategist.bestMoveForActivePlayer() as? TicTacToeMove
        return randomLegalMove()
    }

    /** Easy mode: uniformly random among legal moves — see docs/GAME_DESIGN.md's "AI difficulty" section. */
    private fun randomLegalMove(): TicTacToeMove? {
        val updates =
            match.gameModel.activePlayer
                ?.let { match.gameModel.gameModelUpdates(it) }
                ?.filterIsInstance<TicTacToeMove>()
                ?.takeIf { it.isNotEmpty() }
                ?: return null
        val index = GKRandomDistribution(lowestValue = 0, highestValue = updates.size - 1).nextInt()
        return updates[index]
    }

    override fun isValidNextState(stateClass: KClass<out GKState>): Boolean = stateClass == TurnEndState::class
}
