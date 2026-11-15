import GameplayKit

/// A fixed `X`/`O` player identity, mirroring GameplayKit's `GKGameModelPlayer`. See
/// `docs/GAME_DESIGN.md`'s "Game model" section.
public final class TicTacToePlayer: NSObject, GKGameModelPlayer {
    public let mark: Mark
    public let playerId: Int

    private init(mark: Mark) {
        self.mark = mark
        playerId = mark == .x ? 0 : 1
    }

    public static let x = TicTacToePlayer(mark: .x)
    public static let o = TicTacToePlayer(mark: .o)

    /// Both players, `X` then `O` — `TicTacToeGameModel.players`' fixed value.
    public static let all: [TicTacToePlayer] = [x, o]

    public static func player(for mark: Mark) -> TicTacToePlayer {
        mark == .x ? x : o
    }
}
