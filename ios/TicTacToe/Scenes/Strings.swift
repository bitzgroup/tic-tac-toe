import Foundation

/// Every user-facing string, looked up from `Resources/Localizable.xcstrings` — see
/// `docs/GAME_DESIGN.md`'s "Localization" section for the full key table. No scene ever embeds a
/// string literal directly.
enum Strings {
    static var menuTitle: String {
        String(localized: "menu_title", defaultValue: "Tic-Tac-Toe")
    }

    static var difficultyEasy: String {
        String(localized: "difficulty_easy", defaultValue: "Easy")
    }

    static var difficultyNormal: String {
        String(localized: "difficulty_normal", defaultValue: "Normal")
    }

    static var difficultyHard: String {
        String(localized: "difficulty_hard", defaultValue: "Hard")
    }

    static func yourTurn(_ mark: Mark) -> String {
        let format = String(localized: "status_your_turn", defaultValue: "Your turn (%@)")
        return String(format: format, mark.displayString)
    }

    static var cpuThinking: String {
        String(localized: "status_cpu_thinking", defaultValue: "CPU thinking…")
    }

    static var youWin: String {
        String(localized: "status_you_win", defaultValue: "You win!")
    }

    static var cpuWins: String {
        String(localized: "status_cpu_wins", defaultValue: "CPU wins")
    }

    static var draw: String {
        String(localized: "status_draw", defaultValue: "Draw")
    }

    static func scoreRow(x: Int, o: Int, draws: Int) -> String {
        let format = String(localized: "score_row", defaultValue: "X: %d  O: %d  Draws: %d")
        return String(format: format, x, o, draws)
    }

    static var newGame: String {
        String(localized: "new_game", defaultValue: "New Game")
    }
}

extension Mark {
    /// `"X"`/`"O"` — never translated, see `docs/GAME_DESIGN.md`'s "Localization" section.
    var displayString: String { self == .x ? "X" : "O" }
}
