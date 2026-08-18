import GameplayKit

/// Checks whether the game just ended; routes to `GameOverState` or back to `TurnBeginState` for
/// the next turn. See `docs/GAME_DESIGN.md`'s "Turn flow" section.
final class TurnEndState: GKState {
    unowned let match: TicTacToeMatch

    init(match: TicTacToeMatch) {
        self.match = match
    }

    override func didEnter(from previousState: GKState?) {
        if match.gameModel.board.isGameOver {
            _ = stateMachine?.enter(GameOverState.self)
        } else {
            _ = stateMachine?.enter(TurnBeginState.self)
        }
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == GameOverState.self || stateClass == TurnBeginState.self
    }
}
