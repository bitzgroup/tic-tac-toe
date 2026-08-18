package jp.co.bitz.tictactoe.scenes

import android.graphics.Color
import android.graphics.Path
import android.graphics.RectF
import jp.co.bitz.spritekit.SKLabelNode
import jp.co.bitz.spritekit.SKLabelVerticalAlignmentMode
import jp.co.bitz.spritekit.SKShapeNode
import jp.co.bitz.spritekit.SKTouch
import jp.co.bitz.spritekit.Vector2

/**
 * One of `GameScene`'s 9 invisible, tappable per-cell hit targets — exercises per-node touch
 * dispatch rather than a single scene-level touch handler with manual hit-testing, per
 * docs/GAME_DESIGN.md's "Presentation" section.
 */
public class CellNode(
    public val cellIndex: Int,
) : SKShapeNode() {
    public var onTap: ((Int) -> Unit)? = null

    init {
        isUserInteractionEnabled = true
    }

    override fun touchesBegan(touch: SKTouch) {
        onTap?.invoke(cellIndex)
    }
}

/**
 * A tappable rectangular button with a centered label — shared by `MenuScene`'s difficulty
 * options and `GameScene`'s New Game button.
 */
public class ButtonNode(
    size: Vector2,
    cornerRadius: Float,
    label: String,
    fontSize: Float,
) : SKShapeNode() {
    public var onTap: (() -> Unit)? = null

    init {
        isUserInteractionEnabled = true
        path =
            Path().apply {
                addRoundRect(
                    RectF(-size.x / 2f, -size.y / 2f, size.x / 2f, size.y / 2f),
                    cornerRadius,
                    cornerRadius,
                    Path.Direction.CW,
                )
            }
        strokeColor = Color.WHITE
        lineWidth = 4f
        fillColor = Color.TRANSPARENT

        val text =
            SKLabelNode(label).apply {
                this.fontSize = fontSize
                fontColor = Color.WHITE
                verticalAlignmentMode = SKLabelVerticalAlignmentMode.Center
            }
        addChild(text)
    }

    override fun touchesBegan(touch: SKTouch) {
        onTap?.invoke()
    }
}
