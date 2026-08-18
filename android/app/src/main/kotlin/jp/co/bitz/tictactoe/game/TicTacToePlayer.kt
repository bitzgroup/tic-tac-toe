package jp.co.bitz.tictactoe.game

import jp.co.bitz.gameplaykit.GKGameModelPlayer

/**
 * A fixed X/O player identity, mirroring GameplayKit's `GKGameModelPlayer`. See
 * docs/GAME_DESIGN.md's "Game model" section.
 */
public class TicTacToePlayer private constructor(
    public val mark: Mark,
) : GKGameModelPlayer {
    override val playerId: Int = if (mark == Mark.X) 0 else 1

    public companion object {
        public val x: TicTacToePlayer = TicTacToePlayer(Mark.X)
        public val o: TicTacToePlayer = TicTacToePlayer(Mark.O)

        /** Both players, X then O — [TicTacToeGameModel.players]' fixed value. */
        public val all: List<TicTacToePlayer> = listOf(x, o)

        public fun player(mark: Mark): TicTacToePlayer = if (mark == Mark.X) x else o
    }
}
