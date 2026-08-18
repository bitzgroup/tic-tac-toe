import GameplayKit

/// Conforms `TicTacToeBoard` to `GKGameModel` by wrapping it — see `docs/GAME_DESIGN.md`'s "Game
/// model" section for why this is a separate type from the board's own rules.
public final class TicTacToeGameModel: NSObject, GKGameModel {
    public private(set) var board: TicTacToeBoard

    public init(board: TicTacToeBoard = TicTacToeBoard()) {
        self.board = board
    }

    public var players: [GKGameModelPlayer]? { TicTacToePlayer.all }

    public var activePlayer: GKGameModelPlayer? { TicTacToePlayer.player(for: board.activeMark) }

    public func copy(with zone: NSZone? = nil) -> Any {
        TicTacToeGameModel(board: board)
    }

    public func setGameModel(_ gameModel: GKGameModel) {
        guard let other = gameModel as? TicTacToeGameModel else { return }
        board = other.board
    }

    public func gameModelUpdates(for player: GKGameModelPlayer) -> [GKGameModelUpdate]? {
        guard let player = player as? TicTacToePlayer,
              player.mark == board.activeMark,
              !board.isGameOver
        else {
            return nil
        }
        return board.legalMoves.map { TicTacToeMove(cellIndex: $0) }
    }

    public func apply(_ gameModelUpdate: GKGameModelUpdate) {
        guard let move = gameModelUpdate as? TicTacToeMove else { return }
        board.applyMove(at: move.cellIndex)
    }

    public func score(for player: GKGameModelPlayer) -> Int {
        guard let player = player as? TicTacToePlayer else { return 0 }
        if board.isWin(for: player.mark) { return 1 }
        if board.isLoss(for: player.mark) { return -1 }
        return 0
    }

    public func isWin(for player: GKGameModelPlayer) -> Bool {
        guard let player = player as? TicTacToePlayer else { return false }
        return board.isWin(for: player.mark)
    }

    public func isLoss(for player: GKGameModelPlayer) -> Bool {
        guard let player = player as? TicTacToePlayer else { return false }
        return board.isLoss(for: player.mark)
    }

    public func unapplyGameModelUpdate(_ gameModelUpdate: GKGameModelUpdate) {
        // GKMinmaxStrategist/GKMonteCarloStrategist mutate-and-backtrack a shared model instance
        // during search — apply a candidate move, recurse, unapply it again — identically on
        // Android's bitzgroup/GameplayKit port, so this must be a real inverse of apply(_:) here,
        // matching TicTacToeGameModel.kt exactly. See docs/GAME_DESIGN.md's "Game model" section.
        guard let move = gameModelUpdate as? TicTacToeMove else { return }
        board.unapplyMove(at: move.cellIndex)
    }
}
