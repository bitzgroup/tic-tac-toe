/// In-memory session score — X / O / Draws — see `docs/GAME_DESIGN.md`'s "Score row" bullet.
/// Resets on app relaunch; no persistence layer. A reference type so `GameScene` can hand the
/// same running total forward to the next `GameScene` on "New Game".
final class Score {
    var x = 0
    var o = 0
    var draws = 0
}
