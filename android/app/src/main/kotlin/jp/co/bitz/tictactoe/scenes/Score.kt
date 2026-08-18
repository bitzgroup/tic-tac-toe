package jp.co.bitz.tictactoe.scenes

/**
 * In-memory session score — X / O / Draws — see docs/GAME_DESIGN.md's "Score row" bullet.
 * Resets on app relaunch; no persistence layer. A reference type so `GameScene` can hand the same
 * running total forward to the next `GameScene` on "New Game".
 */
public class Score {
    public var x: Int = 0
    public var o: Int = 0
    public var draws: Int = 0
}
