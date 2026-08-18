import GameplayKit

/// Records which player and cell a placed mark's entity belongs to — see `docs/GAME_DESIGN.md`'s
/// "Marks as entities" section. An ordinary `GKComponent`, not part of GKSKBridge.
final class TicTacToeMarkComponent: GKComponent {
    let player: TicTacToePlayer
    let cellIndex: Int

    init(player: TicTacToePlayer, cellIndex: Int) {
        self.player = player
        self.cellIndex = cellIndex
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
