import Foundation

/// The mark placed in a cell: `.x` or `.o`.
public enum Mark: Equatable {
    case x, o

    var other: Mark { self == .x ? .o : .x }
}

/// Tic-Tac-Toe's rules — no GameplayKit dependency, so it's directly unit-testable. See
/// `docs/GAME_DESIGN.md`'s "Game model" section.
public struct TicTacToeBoard {
    /// The 8 winning lines: 3 rows, 3 columns, 2 diagonals — cell indices 0–8, row-major.
    static let winningLines: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6],
    ]

    /// The board's 9 cells, row-major, `nil` where empty.
    public private(set) var cells: [Mark?]

    /// Whose turn it is.
    public private(set) var activeMark: Mark

    public init() {
        cells = Array(repeating: nil, count: 9)
        activeMark = .x
    }

    /// The 3 cell indices of the completed winning line, or `nil` if there isn't one yet. Lets
    /// the SpriteKit layer highlight the line that won — see `docs/GAME_DESIGN.md`'s "Win
    /// highlight" bullet.
    public var winningLine: [Int]? {
        Self.winningLines.first { line in
            guard let first = cells[line[0]] else { return false }
            return line.allSatisfy { cells[$0] == first }
        }
    }

    /// The mark occupying all three cells of a winning line, or `nil` if there isn't one yet.
    public var winner: Mark? {
        winningLine.flatMap { cells[$0[0]] }
    }

    /// Empty cell indices, in ascending order, or empty once the game has ended.
    public var legalMoves: [Int] {
        guard winner == nil else { return [] }
        return cells.indices.filter { cells[$0] == nil }
    }

    /// `true` once there's a winner or no empty cells remain.
    public var isGameOver: Bool {
        winner != nil || legalMoves.isEmpty
    }

    /// Places `activeMark` at `cellIndex` and advances the turn. `cellIndex` must be empty.
    public mutating func applyMove(at cellIndex: Int) {
        precondition(cells[cellIndex] == nil, "cell \(cellIndex) is already occupied")
        cells[cellIndex] = activeMark
        activeMark = activeMark.other
    }

    /// Reverses `applyMove(at:)`: clears `cellIndex` and reverts `activeMark` to the player who
    /// made that move. Must only be called to undo the move most recently applied at
    /// `cellIndex` — see `TicTacToeGameModel.unapplyGameModelUpdate(_:)`.
    public mutating func unapplyMove(at cellIndex: Int) {
        precondition(cells[cellIndex] != nil, "cell \(cellIndex) is not occupied")
        cells[cellIndex] = nil
        activeMark = activeMark.other
    }

    /// Whether `mark` has three in a row.
    public func isWin(for mark: Mark) -> Bool {
        winner == mark
    }

    /// Whether the *other* mark has three in a row.
    public func isLoss(for mark: Mark) -> Bool {
        guard let winner else { return false }
        return winner != mark
    }
}
