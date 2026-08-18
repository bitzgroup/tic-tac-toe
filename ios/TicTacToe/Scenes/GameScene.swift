import GameplayKit
import SpriteKit

/// The 3×3 board scene: grid, tappable cells, mark entities, status/score labels, win-line
/// pulse, and the New Game button. See `docs/GAME_DESIGN.md`'s "Presentation" and "Marks as
/// entities" sections.
final class GameScene: SKScene {
    private enum Layout {
        static let boardSize: CGFloat = 900
        static let boardCenterY: CGFloat = 1000
        static let cellSize: CGFloat = boardSize / 3
        static let gridLineWidth: CGFloat = 6
        static let markLineWidth: CGFloat = 16
        static let markInset: CGFloat = 40
        static let statusY: CGFloat = 1650
        static let statusFontSize: CGFloat = 56
        static let scoreY: CGFloat = 430
        static let scoreFontSize: CGFloat = 40
        static let newGameButtonY: CGFloat = 250
        static let newGameButtonSize = CGSize(width: 420, height: 110)
        static let newGameCornerRadius: CGFloat = 20
        static let newGameFontSize: CGFloat = 40
        static let placementDuration: TimeInterval = 0.15
        static let thinkingDelay: TimeInterval = 0.4
        static let winPulseScale: CGFloat = 1.15
        static let winPulseDuration: TimeInterval = 0.15
        static let winPulseCount = 2
    }

    private let difficulty: Difficulty
    private let humanMark: Mark
    private let match: TicTacToeMatch
    private let gkScene = GKScene()
    private let score: Score

    private var statusLabel: SKLabelNode!
    private var scoreLabel: SKLabelNode!
    private var markNodesByCell: [Int: SKShapeNode] = [:]

    init(size: CGSize, difficulty: Difficulty, humanMark: Mark, score: Score = Score()) {
        self.difficulty = difficulty
        self.humanMark = humanMark
        self.match = TicTacToeMatch(difficulty: difficulty, humanMark: humanMark)
        self.score = score
        super.init(size: size)
        scaleMode = .aspectFit
        backgroundColor = .black
        gkScene.rootNode = self
        buildContent()
        beginMatch()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Content

    private func buildContent() {
        addChild(makeGridNode())

        for cellIndex in 0..<9 {
            let cell = CellNode(cellIndex: cellIndex)
            cell.path = CGPath(
                rect: CGRect(x: -Layout.cellSize / 2, y: -Layout.cellSize / 2, width: Layout.cellSize, height: Layout.cellSize),
                transform: nil
            )
            cell.strokeColor = .clear
            cell.fillColor = .clear
            cell.position = cellPosition(cellIndex)
            cell.onTap = { [weak self] index in self?.handleCellTapped(index) }
            addChild(cell)
        }

        let status = SKLabelNode(text: "")
        status.fontSize = Layout.statusFontSize
        status.fontColor = .white
        status.position = CGPoint(x: size.width / 2, y: Layout.statusY)
        addChild(status)
        statusLabel = status

        let scoreNode = SKLabelNode(text: "")
        scoreNode.fontSize = Layout.scoreFontSize
        scoreNode.fontColor = .white
        scoreNode.position = CGPoint(x: size.width / 2, y: Layout.scoreY)
        addChild(scoreNode)
        scoreLabel = scoreNode
        refreshScoreLabel()

        let newGameButton = ButtonNode(
            size: Layout.newGameButtonSize,
            cornerRadius: Layout.newGameCornerRadius,
            label: Strings.newGame,
            fontSize: Layout.newGameFontSize
        )
        newGameButton.position = CGPoint(x: size.width / 2, y: Layout.newGameButtonY)
        newGameButton.onTap = { [weak self] in self?.startNewGame() }
        addChild(newGameButton)
    }

    private func makeGridNode() -> SKNode {
        let half = Layout.boardSize / 2
        let path = CGMutablePath()
        for i in 1...2 {
            let offset = -half + Layout.cellSize * CGFloat(i)
            path.move(to: CGPoint(x: offset, y: -half))
            path.addLine(to: CGPoint(x: offset, y: half))
            path.move(to: CGPoint(x: -half, y: offset))
            path.addLine(to: CGPoint(x: half, y: offset))
        }
        path.addRect(CGRect(x: -half, y: -half, width: Layout.boardSize, height: Layout.boardSize))

        let grid = SKShapeNode(path: path)
        grid.strokeColor = .white
        grid.lineWidth = Layout.gridLineWidth
        grid.position = CGPoint(x: size.width / 2, y: Layout.boardCenterY)
        return grid
    }

    private func cellPosition(_ cellIndex: Int) -> CGPoint {
        let row = cellIndex / 3
        let col = cellIndex % 3
        let half = Layout.boardSize / 2
        let x = size.width / 2 - half + Layout.cellSize * (CGFloat(col) + 0.5)
        let y = Layout.boardCenterY + half - Layout.cellSize * (CGFloat(row) + 0.5)
        return CGPoint(x: x, y: y)
    }

    // MARK: - Turn flow

    /// Starts the state machine and, if the coin toss gave the CPU the opening move,
    /// `AITurnState.didEnter` has already applied it synchronously by the time `match.start()`
    /// returns. Defer *revealing* that move (not computing it) so the CPU's "thinking" pause
    /// reads consistently whether it moves first or second — see `docs/GAME_DESIGN.md`'s "AI
    /// thinking delay" bullet.
    private func beginMatch() {
        let boardBefore = match.gameModel.board
        match.start()
        if let aiCellIndex = newlyOccupiedCell(comparingTo: boardBefore) {
            revealAIMove(at: aiCellIndex)
        } else {
            refreshStatusLabel()
        }
    }

    private func handleCellTapped(_ cellIndex: Int) {
        guard let humanState = match.stateMachine.currentState as? HumanTurnState else { return }
        let boardBefore = match.gameModel.board
        guard humanState.applyHumanMove(at: cellIndex) else { return }

        placeMark(player: TicTacToePlayer.player(for: humanMark), cellIndex: cellIndex)

        if let aiCellIndex = newlyOccupiedCell(comparingTo: boardBefore, excluding: cellIndex) {
            revealAIMove(at: aiCellIndex)
        } else {
            finishTurn()
        }
    }

    /// The cell the AI's move landed on, found by diffing the board — `AITurnState.didEnter`
    /// (Phase 1) applies the move synchronously, so this recovers *where* it played rather than
    /// re-triggering search.
    private func newlyOccupiedCell(comparingTo before: TicTacToeBoard, excluding: Int? = nil) -> Int? {
        let after = match.gameModel.board
        return (0..<9).first { $0 != excluding && before.cells[$0] == nil && after.cells[$0] != nil }
    }

    private func revealAIMove(at cellIndex: Int) {
        statusLabel.text = Strings.cpuThinking
        run(.sequence([
            .wait(forDuration: Layout.thinkingDelay),
            .run { [weak self] in
                guard let self else { return }
                self.placeMark(player: TicTacToePlayer.player(for: self.humanMark.other), cellIndex: cellIndex)
                self.finishTurn()
            },
        ]))
    }

    private func finishTurn() {
        if match.gameModel.board.isGameOver {
            handleGameOver()
        } else {
            refreshStatusLabel()
        }
    }

    // MARK: - Marks

    private func placeMark(player: TicTacToePlayer, cellIndex: Int) {
        let markNode = makeMarkNode(for: player.mark)
        markNode.position = cellPosition(cellIndex)
        markNode.setScale(0)
        markNode.alpha = 0
        addChild(markNode)
        markNodesByCell[cellIndex] = markNode

        gkScene.addEntity(TicTacToeMarkEntity(player: player, cellIndex: cellIndex, node: markNode))

        markNode.run(.group([
            SKAction.scale(to: 1, duration: Layout.placementDuration),
            SKAction.fadeAlpha(to: 1, duration: Layout.placementDuration),
        ]))
    }

    private func makeMarkNode(for mark: Mark) -> SKShapeNode {
        let radius = Layout.cellSize / 2 - Layout.markInset
        let path = CGMutablePath()
        switch mark {
        case .x:
            path.move(to: CGPoint(x: -radius, y: -radius))
            path.addLine(to: CGPoint(x: radius, y: radius))
            path.move(to: CGPoint(x: -radius, y: radius))
            path.addLine(to: CGPoint(x: radius, y: -radius))
        case .o:
            path.addEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        }

        let node = SKShapeNode(path: path)
        node.strokeColor = .white
        node.lineWidth = Layout.markLineWidth
        node.fillColor = .clear
        return node
    }

    // MARK: - Status / score / game over

    private func refreshStatusLabel() {
        statusLabel.text = Strings.yourTurn(humanMark)
    }

    private func refreshScoreLabel() {
        scoreLabel.text = Strings.scoreRow(x: score.x, o: score.o, draws: score.draws)
    }

    private func handleGameOver() {
        let board = match.gameModel.board
        if let winningLine = board.winningLine {
            pulseWinningLine(winningLine)
        }

        switch board.winner {
        case .x:
            score.x += 1
            statusLabel.text = statusText(for: .x)
        case .o:
            score.o += 1
            statusLabel.text = statusText(for: .o)
        case nil:
            score.draws += 1
            statusLabel.text = Strings.draw
        }
        refreshScoreLabel()
    }

    private func statusText(for winner: Mark) -> String {
        winner == humanMark ? Strings.youWin : Strings.cpuWins
    }

    private func pulseWinningLine(_ line: [Int]) {
        let pulse = SKAction.sequence([
            SKAction.scale(to: Layout.winPulseScale, duration: Layout.winPulseDuration),
            SKAction.scale(to: 1, duration: Layout.winPulseDuration),
        ])
        let repeated = SKAction.repeat(pulse, count: Layout.winPulseCount)
        for cellIndex in line {
            markNodesByCell[cellIndex]?.run(repeated)
        }
    }

    // MARK: - New Game

    private func startNewGame() {
        let nextScene = GameScene(size: size, difficulty: difficulty, humanMark: humanMark, score: score)
        view?.presentScene(nextScene, transition: .crossFade(withDuration: 0.5))
    }
}
