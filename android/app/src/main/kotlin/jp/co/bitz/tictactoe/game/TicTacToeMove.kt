package jp.co.bitz.tictactoe.game

import jp.co.bitz.gameplaykit.GKGameModelUpdate

/**
 * A move: place the active player's mark at [cellIndex]. Mirrors GameplayKit's
 * `GKGameModelUpdate`.
 */
public class TicTacToeMove(
    public val cellIndex: Int,
) : GKGameModelUpdate {
    override var value: Int = 0
}
