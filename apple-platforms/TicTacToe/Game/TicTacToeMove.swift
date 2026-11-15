import GameplayKit

/// A move: place the active player's mark at `cellIndex`. Mirrors GameplayKit's
/// `GKGameModelUpdate`.
public final class TicTacToeMove: NSObject, GKGameModelUpdate {
    public let cellIndex: Int
    public var value: Int = 0

    public init(cellIndex: Int) {
        self.cellIndex = cellIndex
    }
}
