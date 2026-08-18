package jp.co.bitz.tictactoe.game

import jp.co.bitz.gameplaykit.GKMinmaxStrategist
import jp.co.bitz.gameplaykit.GKMonteCarloStrategist
import jp.co.bitz.gameplaykit.GKRandomSource
import jp.co.bitz.gameplaykit.GKStateMachine
import jp.co.bitz.gameplaykit.GKStrategist
import jp.co.bitz.tictactoe.game.states.AITurnState
import jp.co.bitz.tictactoe.game.states.GameOverState
import jp.co.bitz.tictactoe.game.states.HumanTurnState
import jp.co.bitz.tictactoe.game.states.TurnBeginState
import jp.co.bitz.tictactoe.game.states.TurnEndState

/**
 * Which GameplayKit AI approach drives the CPU's moves this game — see docs/GAME_DESIGN.md's
 * "AI difficulty → GameplayKit strategist" section.
 */
public enum class Difficulty {
    EASY,
    NORMAL,
    HARD,
}

/**
 * Coordinates one game: the [TicTacToeGameModel], which mark the human plays (decided by the coin
 * toss), the difficulty-appropriate strategist, and the [GKStateMachine] driving turns. See
 * docs/GAME_DESIGN.md's "Game model" and "Turn flow" sections.
 *
 * Constructed via [create] rather than directly: building the state machine needs a fully
 * constructed [TicTacToeMatch] to hand each [jp.co.bitz.gameplaykit.GKState] a reference to, which
 * a plain constructor/init block can't safely provide (detekt's `LeakingThis` rule exists for
 * exactly this reason — passing `this` out of a class during its own construction).
 */
public class TicTacToeMatch private constructor(
    public val difficulty: Difficulty,
    public val humanMark: Mark,
) {
    public val gameModel: TicTacToeGameModel = TicTacToeGameModel()
    internal val strategist: GKStrategist? = createStrategist(difficulty, gameModel)

    public lateinit var stateMachine: GKStateMachine
        private set

    private fun attachStateMachine() {
        stateMachine =
            GKStateMachine(
                listOf(
                    TurnBeginState(this),
                    HumanTurnState(this),
                    AITurnState(this),
                    TurnEndState(this),
                    GameOverState(),
                ),
            )
    }

    /**
     * Starts the match: enters [TurnBeginState], which immediately routes to [HumanTurnState] or
     * [AITurnState] depending on [humanMark] and `gameModel.activePlayer`.
     */
    public fun start() {
        stateMachine.enter<TurnBeginState>()
    }

    public companion object {
        public fun create(
            difficulty: Difficulty,
            humanMark: Mark = coinTossMark(),
        ): TicTacToeMatch {
            val match = TicTacToeMatch(difficulty, humanMark)
            match.attachStateMachine()
            return match
        }

        /**
         * Flips a coin (`GKRandomSource.sharedRandom().nextBool()`) to decide who plays X — see
         * docs/GAME_DESIGN.md's "Randomization" section.
         */
        public fun coinTossMark(): Mark = if (GKRandomSource.sharedRandom().nextBool()) Mark.X else Mark.O

        private fun createStrategist(
            difficulty: Difficulty,
            model: TicTacToeGameModel,
        ): GKStrategist? =
            when (difficulty) {
                Difficulty.EASY -> null
                Difficulty.NORMAL ->
                    GKMonteCarloStrategist().apply {
                        budget = 200
                        gameModel = model
                    }
                Difficulty.HARD ->
                    GKMinmaxStrategist().apply {
                        maxLookAheadDepth = 9
                        gameModel = model
                    }
            }
    }
}
