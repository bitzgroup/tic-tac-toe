package jp.co.bitz.tictactoe.scenes

import android.content.Context
import android.graphics.Color
import jp.co.bitz.spritekit.SKLabelNode
import jp.co.bitz.spritekit.SKScene
import jp.co.bitz.spritekit.SKSceneScaleMode
import jp.co.bitz.spritekit.SKTransition
import jp.co.bitz.spritekit.Vector2
import jp.co.bitz.tictactoe.game.Difficulty
import jp.co.bitz.tictactoe.game.TicTacToeMatch
import kotlin.time.Duration.Companion.seconds

/**
 * The app's entry scene: difficulty picker → coin toss → `GameScene`. See
 * docs/GAME_DESIGN.md's "Presentation" section, `MenuScene`.
 */
public class MenuScene(
    private val context: Context,
    size: Vector2,
) : SKScene(size) {
    private object Layout {
        const val TITLE_Y = 1450f
        const val TITLE_FONT_SIZE = 84f
        val BUTTON_SIZE = Vector2(560f, 140f)
        const val BUTTON_FONT_SIZE = 48f
        const val FIRST_BUTTON_Y = 1050f
        const val BUTTON_SPACING = 200f
    }

    init {
        scaleMode = SKSceneScaleMode.AspectFit
        backgroundColor = Color.BLACK
        buildContent()
    }

    private fun buildContent() {
        val strings = Strings(context)

        val title =
            SKLabelNode(strings.menuTitle).apply {
                fontSize = Layout.TITLE_FONT_SIZE
                fontColor = Color.WHITE
                position = Vector2(size.x / 2f, Layout.TITLE_Y)
            }
        addChild(title)

        val difficulties =
            listOf(
                Difficulty.EASY to strings.difficultyEasy,
                Difficulty.NORMAL to strings.difficultyNormal,
                Difficulty.HARD to strings.difficultyHard,
            )
        difficulties.forEachIndexed { index, (difficulty, label) ->
            val button =
                ButtonNode(
                    size = Layout.BUTTON_SIZE,
                    cornerRadius = 24f,
                    label = label,
                    fontSize = Layout.BUTTON_FONT_SIZE,
                )
            button.position = Vector2(size.x / 2f, Layout.FIRST_BUTTON_Y - index * Layout.BUTTON_SPACING)
            button.onTap = { startGame(difficulty) }
            addChild(button)
        }
    }

    private fun startGame(difficulty: Difficulty) {
        val humanMark = TicTacToeMatch.coinTossMark()
        val nextScene = GameScene(context, size, difficulty, humanMark)
        view?.presentScene(nextScene, SKTransition.crossFade(0.5.seconds))
    }
}
