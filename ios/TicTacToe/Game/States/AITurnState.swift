import GameplayKit

/// Asks the difficulty-appropriate strategist (or, on Easy, `GKRandomDistribution`) for a move
/// and applies it. See `docs/GAME_DESIGN.md`'s "AI difficulty → GameplayKit strategist" and "Turn
/// flow" sections. No artificial delay here — the visible "CPU thinking…" pause is a SpriteKit
/// concern (Phase 2).
final class AITurnState: GKState {
    unowned let match: TicTacToeMatch

    init(match: TicTacToeMatch) {
        self.match = match
    }

    override func didEnter(from previousState: GKState?) {
        guard let move = bestMove() else { return }
        match.gameModel.apply(move)
        _ = stateMachine?.enter(TurnEndState.self)
    }

    private func bestMove() -> TicTacToeMove? {
        if let strategist = match.strategist {
            return strategist.bestMoveForActivePlayer() as? TicTacToeMove
        }
        guard let activePlayer = match.gameModel.activePlayer,
              let updates = match.gameModel.gameModelUpdates(for: activePlayer) as? [TicTacToeMove],
              !updates.isEmpty
        else {
            return nil
        }
        let index = GKRandomDistribution(lowestValue: 0, highestValue: updates.count - 1).nextInt()
        return updates[index]
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass == TurnEndState.self
    }
}
