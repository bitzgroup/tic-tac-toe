package jp.co.bitz.tictactoe.scenes

import android.content.Context
import jp.co.bitz.tictactoe.R
import jp.co.bitz.tictactoe.game.Mark

/**
 * Every user-facing string, looked up from `res/values/strings.xml` (`res/values-ja/strings.xml`
 * for Japanese) — see docs/GAME_DESIGN.md's "Localization" section for the full key table. No
 * scene ever embeds a string literal directly.
 */
public class Strings(
    private val context: Context,
) {
    public val menuTitle: String get() = context.getString(R.string.menu_title)
    public val difficultyEasy: String get() = context.getString(R.string.difficulty_easy)
    public val difficultyNormal: String get() = context.getString(R.string.difficulty_normal)
    public val difficultyHard: String get() = context.getString(R.string.difficulty_hard)

    public fun yourTurn(mark: Mark): String = context.getString(R.string.status_your_turn, mark.displayString)

    public val cpuThinking: String get() = context.getString(R.string.status_cpu_thinking)
    public val youWin: String get() = context.getString(R.string.status_you_win)
    public val cpuWins: String get() = context.getString(R.string.status_cpu_wins)
    public val draw: String get() = context.getString(R.string.status_draw)

    public fun scoreRow(
        x: Int,
        o: Int,
        draws: Int,
    ): String = context.getString(R.string.score_row, x, o, draws)

    public val newGame: String get() = context.getString(R.string.new_game)
}

/** "X"/"O" — never translated, see docs/GAME_DESIGN.md's "Localization" section. */
public val Mark.displayString: String get() = if (this == Mark.X) "X" else "O"
