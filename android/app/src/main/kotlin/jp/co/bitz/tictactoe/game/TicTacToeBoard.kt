package jp.co.bitz.tictactoe.game

/** The mark placed in a cell: X or O. */
public enum class Mark {
    X,
    O,
    ;

    public val other: Mark
        get() = if (this == X) O else X
}

/**
 * Tic-Tac-Toe's rules — no GameplayKit dependency, so it's directly unit-testable. See
 * docs/GAME_DESIGN.md's "Game model" section.
 *
 * [cells] is always replaced wholesale on [applyMove]/[unapplyMove] rather than mutated in place,
 * so [copy] sharing the same list reference with the original is safe — matches the true-deep-copy
 * semantics [jp.co.bitz.tictactoe.game.TicTacToeGameModel.copy] requires without needing an
 * explicit deep-copy step here.
 */
public class TicTacToeBoard private constructor(
    cells: List<Mark?>,
    activeMark: Mark,
) {
    public constructor() : this(List(CELL_COUNT) { null }, Mark.X)

    /** The board's 9 cells, row-major, null where empty. */
    public var cells: List<Mark?> = cells
        private set

    /** Whose turn it is. */
    public var activeMark: Mark = activeMark
        private set

    /**
     * The 3 cell indices of the completed winning line, or null if there isn't one yet. Lets the
     * SpriteKit layer highlight the line that won — see docs/GAME_DESIGN.md's "Win highlight"
     * bullet.
     */
    public val winningLine: List<Int>?
        get() =
            WINNING_LINES.firstOrNull { line ->
                val first = cells[line[0]] ?: return@firstOrNull false
                line.all { cells[it] == first }
            }

    /** The mark occupying all three cells of a winning line, or null if there isn't one yet. */
    public val winner: Mark?
        get() = winningLine?.let { cells[it[0]] }

    /** Empty cell indices, in ascending order, or empty once the game has ended. */
    public val legalMoves: List<Int>
        get() = if (winner != null) emptyList() else cells.indices.filter { cells[it] == null }

    /** True once there's a winner or no empty cells remain. */
    public val isGameOver: Boolean
        get() = winner != null || legalMoves.isEmpty()

    /** Places [activeMark] at [cellIndex] and advances the turn. [cellIndex] must be empty. */
    public fun applyMove(cellIndex: Int) {
        check(cells[cellIndex] == null) { "cell $cellIndex is already occupied" }
        cells = cells.toMutableList().also { it[cellIndex] = activeMark }
        activeMark = activeMark.other
    }

    /**
     * Reverses [applyMove]: clears [cellIndex] and reverts [activeMark] to the player who made
     * that move. Must only be called to undo the move most recently applied at [cellIndex] — see
     * [jp.co.bitz.tictactoe.game.TicTacToeGameModel.unapplyGameModelUpdate].
     */
    public fun unapplyMove(cellIndex: Int) {
        check(cells[cellIndex] != null) { "cell $cellIndex is not occupied" }
        cells = cells.toMutableList().also { it[cellIndex] = null }
        activeMark = activeMark.other
    }

    /** Whether [mark] has three in a row. */
    public fun isWin(mark: Mark): Boolean = winner == mark

    /** Whether the *other* mark has three in a row. */
    public fun isLoss(mark: Mark): Boolean = winner != null && winner != mark

    /** An independent copy — see the class doc for why sharing [cells] is safe. */
    public fun copy(): TicTacToeBoard = TicTacToeBoard(cells, activeMark)

    private companion object {
        const val CELL_COUNT = 9

        /** The 8 winning lines: 3 rows, 3 columns, 2 diagonals — cell indices 0–8, row-major. */
        val WINNING_LINES =
            listOf(
                listOf(0, 1, 2),
                listOf(3, 4, 5),
                listOf(6, 7, 8),
                listOf(0, 3, 6),
                listOf(1, 4, 7),
                listOf(2, 5, 8),
                listOf(0, 4, 8),
                listOf(2, 4, 6),
            )
    }
}
