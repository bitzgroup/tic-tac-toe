import GameplayKit

/// Terminal state for one match — see `docs/GAME_DESIGN.md`'s "Turn flow" section: a new game is
/// a new `TicTacToeMatch`, never a transition back out of this state.
final class GameOverState: GKState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        false
    }
}
