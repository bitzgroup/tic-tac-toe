import GameplayKit
import SpriteKit

/// One `GKEntity` per placed mark, wrapping its `SKShapeNode` — see `docs/GAME_DESIGN.md`'s
/// "Marks as entities" section. Creating this entity does *not* add `node` to the scene tree;
/// `GameScene` still does that itself via a plain `addChild`.
final class TicTacToeMarkEntity: GKEntity {
    let node: SKShapeNode

    init(player: TicTacToePlayer, cellIndex: Int, node: SKShapeNode) {
        self.node = node
        super.init()
        addComponent(TicTacToeMarkComponent(player: player, cellIndex: cellIndex))
        addComponent(GKSKNodeComponent(node: node))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
