import SpriteKit

/// The app's entry scene: difficulty picker → coin toss → `GameScene`. See
/// `docs/GAME_DESIGN.md`'s "Presentation" section, `MenuScene`.
final class MenuScene: SKScene {
    private enum Layout {
        static let titleY: CGFloat = 1450
        static let titleFontSize: CGFloat = 84
        static let buttonSize = CGSize(width: 560, height: 140)
        static let buttonFontSize: CGFloat = 48
        static let firstButtonY: CGFloat = 1050
        static let buttonSpacing: CGFloat = 200
    }

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFit
        backgroundColor = .black
        buildContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildContent() {
        let title = SKLabelNode(text: Strings.menuTitle)
        title.fontSize = Layout.titleFontSize
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: Layout.titleY)
        addChild(title)

        let difficulties: [(Difficulty, String)] = [
            (.easy, Strings.difficultyEasy),
            (.normal, Strings.difficultyNormal),
            (.hard, Strings.difficultyHard),
        ]
        for (index, entry) in difficulties.enumerated() {
            let (difficulty, label) = entry
            let button = ButtonNode(
                size: Layout.buttonSize,
                cornerRadius: 24,
                label: label,
                fontSize: Layout.buttonFontSize
            )
            button.position = CGPoint(x: size.width / 2, y: Layout.firstButtonY - CGFloat(index) * Layout.buttonSpacing)
            button.onTap = { [weak self] in self?.startGame(difficulty: difficulty) }
            addChild(button)
        }
    }

    private func startGame(difficulty: Difficulty) {
        let humanMark = TicTacToeMatch.coinTossMark()
        let nextScene = GameScene(size: size, difficulty: difficulty, humanMark: humanMark)
        view?.presentScene(nextScene, transition: .crossFade(withDuration: 0.5))
    }
}
