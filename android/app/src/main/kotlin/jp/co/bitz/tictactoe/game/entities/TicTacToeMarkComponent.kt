package jp.co.bitz.tictactoe.game.entities

import jp.co.bitz.gameplaykit.GKComponent
import jp.co.bitz.tictactoe.game.TicTacToePlayer

/**
 * Records which player and cell a placed mark's entity belongs to. See docs/GAME_DESIGN.md's
 * "Marks as entities" section.
 */
public class TicTacToeMarkComponent(
    public val player: TicTacToePlayer,
    public val cellIndex: Int,
) : GKComponent()
