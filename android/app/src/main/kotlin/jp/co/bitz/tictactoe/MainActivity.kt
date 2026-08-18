package jp.co.bitz.tictactoe

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import jp.co.bitz.spritekit.Vector2
import jp.co.bitz.spritekit.compose.SKView
import jp.co.bitz.tictactoe.scenes.MenuScene

/**
 * Hosts the game's SpriteKit scenes via `:spritekit-compose`'s [SKView] — the documented,
 * recommended way to use `bitzgroup/SpriteKit` (see its own `docs/ARCHITECTURE.md`). Scene-to-scene
 * navigation (`MenuScene` → `GameScene` → New Game) happens entirely inside the SpriteKit layer via
 * `view?.presentScene(_:transition:)`; Compose only ever presents the first scene.
 */
public class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    val context = LocalContext.current
                    val scene = remember { MenuScene(context, Vector2(1080f, 1920f)) }
                    SKView(scene = scene, modifier = Modifier.fillMaxSize())
                }
            }
        }
    }
}
