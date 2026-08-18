package jp.co.bitz.tictactoe.scenes

import android.content.Context
import android.graphics.Color
import android.graphics.Path
import jp.co.bitz.gkskbridge.GKScene
import jp.co.bitz.spritekit.SKAction
import jp.co.bitz.spritekit.SKLabelNode
import jp.co.bitz.spritekit.SKScene
import jp.co.bitz.spritekit.SKSceneScaleMode
import jp.co.bitz.spritekit.SKShapeNode
import jp.co.bitz.spritekit.SKTransition
import jp.co.bitz.spritekit.Vector2
import jp.co.bitz.tictactoe.game.Difficulty
import jp.co.bitz.tictactoe.game.Mark
import jp.co.bitz.tictactoe.game.TicTacToeBoard
import jp.co.bitz.tictactoe.game.TicTacToeMatch
import jp.co.bitz.tictactoe.game.TicTacToePlayer
import jp.co.bitz.tictactoe.game.entities.TicTacToeMarkEntity
import jp.co.bitz.tictactoe.game.states.HumanTurnState
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds

/**
 * The 3×3 board scene: grid, tappable cells, mark entities, status/score labels, win-line pulse,
 * and the New Game button. See docs/GAME_DESIGN.md's "Presentation" and "Marks as entities"
 * sections.
 */
public class GameScene(
    private val context: Context,
    size: Vector2,
    private val difficulty: Difficulty,
    private val humanMark: Mark,
    private val score: Score = Score(),
) : SKScene(size) {
    private object Layout {
        const val BOARD_SIZE = 900f
        const val BOARD_CENTER_Y = 1000f
        const val CELL_SIZE = BOARD_SIZE / 3f
        const val GRID_LINE_WIDTH = 6f
        const val MARK_LINE_WIDTH = 16f
        const val MARK_INSET = 40f
        const val STATUS_Y = 1650f
        const val STATUS_FONT_SIZE = 56f
        const val SCORE_Y = 430f
        const val SCORE_FONT_SIZE = 40f
        const val NEW_GAME_BUTTON_Y = 250f
        val NEW_GAME_BUTTON_SIZE = Vector2(420f, 110f)
        const val NEW_GAME_CORNER_RADIUS = 20f
        const val NEW_GAME_FONT_SIZE = 40f
        val PLACEMENT_DURATION = 150.milliseconds
        val THINKING_DELAY = 400.milliseconds
        const val WIN_PULSE_SCALE = 1.15f
        val WIN_PULSE_DURATION = 150.milliseconds
        const val WIN_PULSE_COUNT = 2
    }

    private val strings = Strings(context)
    private val match = TicTacToeMatch.create(difficulty, humanMark)
    private val gkScene = GKScene()
    private val markNodesByCell = mutableMapOf<Int, SKShapeNode>()

    private lateinit var statusLabel: SKLabelNode
    private lateinit var scoreLabel: SKLabelNode

    init {
        scaleMode = SKSceneScaleMode.AspectFit
        backgroundColor = Color.BLACK
        gkScene.rootNode = this
        buildContent()
        beginMatch()
    }

    // region Content

    private fun buildContent() {
        addChild(makeGridNode())

        for (cellIndex in 0 until CELL_COUNT) {
            val cell = CellNode(cellIndex)
            cell.path =
                Path().apply {
                    addRect(
                        -Layout.CELL_SIZE / 2f,
                        -Layout.CELL_SIZE / 2f,
                        Layout.CELL_SIZE / 2f,
                        Layout.CELL_SIZE / 2f,
                        Path.Direction.CW,
                    )
                }
            cell.strokeColor = Color.TRANSPARENT
            cell.fillColor = Color.TRANSPARENT
            cell.position = cellPosition(cellIndex)
            cell.onTap = { index -> handleCellTapped(index) }
            addChild(cell)
        }

        statusLabel =
            SKLabelNode("").apply {
                fontSize = Layout.STATUS_FONT_SIZE
                fontColor = Color.WHITE
                position = Vector2(size.x / 2f, Layout.STATUS_Y)
            }
        addChild(statusLabel)

        scoreLabel =
            SKLabelNode("").apply {
                fontSize = Layout.SCORE_FONT_SIZE
                fontColor = Color.WHITE
                position = Vector2(size.x / 2f, Layout.SCORE_Y)
            }
        addChild(scoreLabel)
        refreshScoreLabel()

        val newGameButton =
            ButtonNode(
                size = Layout.NEW_GAME_BUTTON_SIZE,
                cornerRadius = Layout.NEW_GAME_CORNER_RADIUS,
                label = strings.newGame,
                fontSize = Layout.NEW_GAME_FONT_SIZE,
            )
        newGameButton.position = Vector2(size.x / 2f, Layout.NEW_GAME_BUTTON_Y)
        newGameButton.onTap = { startNewGame() }
        addChild(newGameButton)
    }

    private fun makeGridNode(): SKShapeNode {
        val half = Layout.BOARD_SIZE / 2f
        val path =
            Path().apply {
                for (i in 1..2) {
                    val offset = -half + Layout.CELL_SIZE * i
                    moveTo(offset, -half)
                    lineTo(offset, half)
                    moveTo(-half, offset)
                    lineTo(half, offset)
                }
                addRect(-half, -half, half, half, Path.Direction.CW)
            }
        return SKShapeNode(path).apply {
            strokeColor = Color.WHITE
            lineWidth = Layout.GRID_LINE_WIDTH
            position = Vector2(size.x / 2f, Layout.BOARD_CENTER_Y)
        }
    }

    private fun cellPosition(cellIndex: Int): Vector2 {
        val row = cellIndex / 3
        val col = cellIndex % 3
        val half = Layout.BOARD_SIZE / 2f
        val x = size.x / 2f - half + Layout.CELL_SIZE * (col + 0.5f)
        val y = Layout.BOARD_CENTER_Y + half - Layout.CELL_SIZE * (row + 0.5f)
        return Vector2(x, y)
    }

    // endregion

    // region Turn flow

    /**
     * Starts the state machine and, if the coin toss gave the CPU the opening move,
     * `AITurnState.didEnter` has already applied it synchronously by the time `match.start()`
     * returns. Defer *revealing* that move (not computing it) so the CPU's "thinking" pause reads
     * consistently whether it moves first or second — see docs/GAME_DESIGN.md's "AI thinking
     * delay" bullet.
     */
    private fun beginMatch() {
        // .copy() is essential here: unlike iOS's TicTacToeBoard (a Swift struct, copied on
        // assignment), Kotlin's TicTacToeBoard is a plain class — `match.gameModel.board` without
        // .copy() would alias the same mutable instance match.start() goes on to mutate in place,
        // making this snapshot worthless for the before/after diff below.
        val boardBefore = match.gameModel.board.copy()
        match.start()
        val aiCellIndex = newlyOccupiedCell(boardBefore)
        if (aiCellIndex != null) {
            revealAIMove(aiCellIndex)
        } else {
            refreshStatusLabel()
        }
    }

    private fun handleCellTapped(cellIndex: Int) {
        val humanState = match.stateMachine.currentState as? HumanTurnState ?: return
        val boardBefore = match.gameModel.board.copy() // see beginMatch()'s comment on why .copy() is required
        if (!humanState.applyHumanMove(cellIndex)) return

        placeMark(TicTacToePlayer.player(humanMark), cellIndex)

        val aiCellIndex = newlyOccupiedCell(boardBefore, excluding = cellIndex)
        if (aiCellIndex != null) {
            revealAIMove(aiCellIndex)
        } else {
            finishTurn()
        }
    }

    /**
     * The cell the AI's move landed on, found by diffing the board — `AITurnState.didEnter`
     * (Phase 1) applies the move synchronously, so this recovers *where* it played rather than
     * re-triggering search.
     */
    private fun newlyOccupiedCell(
        before: TicTacToeBoard,
        excluding: Int? = null,
    ): Int? {
        val after = match.gameModel.board
        return (0 until CELL_COUNT).firstOrNull {
            it != excluding && before.cells[it] == null && after.cells[it] != null
        }
    }

    private fun revealAIMove(cellIndex: Int) {
        statusLabel.text = strings.cpuThinking
        run(
            SKAction.sequence(
                listOf(
                    SKAction.wait(Layout.THINKING_DELAY),
                    SKAction.run {
                        placeMark(TicTacToePlayer.player(humanMark.other), cellIndex)
                        finishTurn()
                    },
                ),
            ),
        )
    }

    private fun finishTurn() {
        if (match.gameModel.board.isGameOver) {
            handleGameOver()
        } else {
            refreshStatusLabel()
        }
    }

    // endregion

    // region Marks

    private fun placeMark(
        player: TicTacToePlayer,
        cellIndex: Int,
    ) {
        val markNode = makeMarkNode(player.mark)
        markNode.position = cellPosition(cellIndex)
        markNode.xScale = 0f
        markNode.yScale = 0f
        markNode.alpha = 0f
        addChild(markNode)
        markNodesByCell[cellIndex] = markNode

        gkScene.addEntity(TicTacToeMarkEntity(player, cellIndex, markNode))

        markNode.run(
            SKAction.group(
                listOf(
                    SKAction.scaleTo(1f, Layout.PLACEMENT_DURATION),
                    SKAction.fadeAlphaTo(1f, Layout.PLACEMENT_DURATION),
                ),
            ),
        )
    }

    private fun makeMarkNode(mark: Mark): SKShapeNode {
        val radius = Layout.CELL_SIZE / 2f - Layout.MARK_INSET
        val path =
            Path().apply {
                when (mark) {
                    Mark.X -> {
                        moveTo(-radius, -radius)
                        lineTo(radius, radius)
                        moveTo(-radius, radius)
                        lineTo(radius, -radius)
                    }
                    Mark.O -> addOval(-radius, -radius, radius, radius, Path.Direction.CW)
                }
            }
        return SKShapeNode(path).apply {
            strokeColor = Color.WHITE
            lineWidth = Layout.MARK_LINE_WIDTH
            fillColor = Color.TRANSPARENT
        }
    }

    // endregion

    // region Status / score / game over

    private fun refreshStatusLabel() {
        statusLabel.text = strings.yourTurn(humanMark)
    }

    private fun refreshScoreLabel() {
        scoreLabel.text = strings.scoreRow(score.x, score.o, score.draws)
    }

    private fun handleGameOver() {
        val board = match.gameModel.board
        board.winningLine?.let { pulseWinningLine(it) }

        when (val winner = board.winner) {
            Mark.X -> {
                score.x += 1
                statusLabel.text = statusText(winner)
            }
            Mark.O -> {
                score.o += 1
                statusLabel.text = statusText(winner)
            }
            null -> {
                score.draws += 1
                statusLabel.text = strings.draw
            }
        }
        refreshScoreLabel()
    }

    private fun statusText(winner: Mark): String = if (winner == humanMark) strings.youWin else strings.cpuWins

    private fun pulseWinningLine(line: List<Int>) {
        val pulse =
            SKAction.sequence(
                listOf(
                    SKAction.scaleTo(Layout.WIN_PULSE_SCALE, Layout.WIN_PULSE_DURATION),
                    SKAction.scaleTo(1f, Layout.WIN_PULSE_DURATION),
                ),
            )
        val repeated = SKAction.repeat(pulse, Layout.WIN_PULSE_COUNT)
        for (cellIndex in line) {
            markNodesByCell[cellIndex]?.run(repeated)
        }
    }

    // endregion

    // region New Game

    private fun startNewGame() {
        val nextScene = GameScene(context, size, difficulty, humanMark, score)
        view?.presentScene(nextScene, SKTransition.crossFade(0.5.seconds))
    }

    // endregion

    private companion object {
        const val CELL_COUNT = 9
    }
}
