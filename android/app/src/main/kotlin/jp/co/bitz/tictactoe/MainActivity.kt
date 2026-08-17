package jp.co.bitz.tictactoe

import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import jp.co.bitz.spritekit.SKScene
import jp.co.bitz.spritekit.Vector2
import jp.co.bitz.spritekit.compose.SKView

/**
 * Hosts the game's SpriteKit scenes via `:spritekit-compose`'s [SKView] — the documented,
 * recommended way to use `bitzgroup/SpriteKit` (see its own `docs/ARCHITECTURE.md`).
 *
 * Phase 0 scaffolding only: presents a blank [SKScene], no [jp.co.bitz.tictactoe.game]/
 * [jp.co.bitz.tictactoe.scenes] logic wired up yet — see `docs/ROADMAP.md`.
 */
public class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    val scene =
                        remember {
                            SKScene(size = Vector2(1080f, 1920f)).apply {
                                backgroundColor = Color.BLACK
                            }
                        }
                    SKView(scene = scene, modifier = Modifier.fillMaxSize())
                }
            }
        }
    }
}
