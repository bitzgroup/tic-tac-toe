import GameplayKit

/// Routes to `HumanTurnState` or `AITurnState` depending on whose turn it is. See
/// `docs/GAME_DESIGN.md`'s "Turn flow" section.
final class TurnBeginState: GKState {
    unowned let match: TicTacToeMatch

    init(match: TicTacToeMatch) {
        self.match = match
    }

    override func didEnter(from previousState: GKState?) {
        guard let activePlayer = match.gameModel.activePlayer as? TicTacToePlayer else { return }
        if activePlayer.mark == match.humanMark {
            _ = stateMachine?.enter(HumanTurnState.self)
        } else {
            _ = stateMachine?.enter(AITurnState.self)
        }
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == HumanTurnState.self || stateClass == AITurnState.self
    }
}
