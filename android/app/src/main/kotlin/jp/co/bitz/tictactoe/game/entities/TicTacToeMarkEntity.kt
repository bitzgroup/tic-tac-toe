package jp.co.bitz.tictactoe.game.entities

import jp.co.bitz.gameplaykit.GKEntity
import jp.co.bitz.gkskbridge.GKSKNodeComponent
import jp.co.bitz.spritekit.SKShapeNode
import jp.co.bitz.tictactoe.game.TicTacToePlayer

/**
 * One [GKEntity] per placed mark, wrapping its [SKShapeNode] — see docs/GAME_DESIGN.md's "Marks
 * as entities" section. Creating this entity does *not* add [node] to the scene tree; `GameScene`
 * still does that itself via a plain `addChild`.
 */
public class TicTacToeMarkEntity(
    player: TicTacToePlayer,
    cellIndex: Int,
    public val node: SKShapeNode,
) : GKEntity() {
    init {
        addComponent(TicTacToeMarkComponent(player, cellIndex))
        addComponent(GKSKNodeComponent(node))
    }
}
