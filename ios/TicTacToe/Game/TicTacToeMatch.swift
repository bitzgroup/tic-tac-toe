import GameplayKit

/// Which GameplayKit AI approach drives the CPU's moves this game — see `docs/GAME_DESIGN.md`'s
/// "AI difficulty → GameplayKit strategist" section.
public enum Difficulty {
    case easy, normal, hard
}

/// Coordinates one game: the `TicTacToeGameModel`, which mark the human plays (decided by the
/// coin toss), the difficulty-appropriate strategist, and the `GKStateMachine` driving turns. See
/// `docs/GAME_DESIGN.md`'s "Game model" and "Turn flow" sections.
public final class TicTacToeMatch {
    public let gameModel: TicTacToeGameModel
    public let humanMark: Mark
    public let difficulty: Difficulty
    let strategist: GKStrategist?
    public private(set) var stateMachine: GKStateMachine!

    public init(difficulty: Difficulty, humanMark: Mark = TicTacToeMatch.coinTossMark()) {
        let gameModel = TicTacToeGameModel()
        self.gameModel = gameModel
        self.humanMark = humanMark
        self.difficulty = difficulty
        strategist = Self.makeStrategist(for: difficulty, gameModel: gameModel)
        stateMachine = GKStateMachine(states: [
            TurnBeginState(match: self),
            HumanTurnState(match: self),
            AITurnState(match: self),
            TurnEndState(match: self),
            GameOverState(),
        ])
    }

    /// Starts the match: enters `TurnBeginState`, which immediately routes to `HumanTurnState` or
    /// `AITurnState` depending on `humanMark` and `gameModel.activePlayer`.
    public func start() {
        _ = stateMachine.enter(TurnBeginState.self)
    }

    /// Flips a coin (`GKRandomSource.sharedRandom().nextBool()`) to decide who plays `X` — see
    /// `docs/GAME_DESIGN.md`'s "Randomization" section.
    public static func coinTossMark() -> Mark {
        GKRandomSource.sharedRandom().nextBool() ? .x : .o
    }

    private static func makeStrategist(for difficulty: Difficulty, gameModel: TicTacToeGameModel) -> GKStrategist? {
        switch difficulty {
        case .easy:
            return nil
        case .normal:
            let strategist = GKMonteCarloStrategist()
            strategist.budget = 200
            strategist.gameModel = gameModel
            return strategist
        case .hard:
            let strategist = GKMinmaxStrategist()
            strategist.maxLookAheadDepth = 9
            strategist.gameModel = gameModel
            return strategist
        }
    }
}
