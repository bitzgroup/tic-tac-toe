import GameplayKit

/// Waits for the SpriteKit layer (Phase 2) to report a tap via `applyHumanMove(at:)`. See
/// `docs/GAME_DESIGN.md`'s "Turn flow" section.
final class HumanTurnState: GKState {
    unowned let match: TicTacToeMatch

    init(match: TicTacToeMatch) {
        self.match = match
    }

    /// Applies a tap at `cellIndex` if it's a legal move for the active player, advancing to
    /// `TurnEndState`. Returns whether the move was applied.
    @discardableResult
    func applyHumanMove(at cellIndex: Int) -> Bool {
        guard let activePlayer = match.gameModel.activePlayer,
              let updates = match.gameModel.gameModelUpdates(for: activePlayer) as? [TicTacToeMove],
              let move = updates.first(where: { $0.cellIndex == cellIndex })
        else {
            return false
        }
        match.gameModel.apply(move)
        return stateMachine?.enter(TurnEndState.self) ?? false
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == TurnEndState.self
    }
}
