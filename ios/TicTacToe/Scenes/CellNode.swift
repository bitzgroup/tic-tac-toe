import SpriteKit
import UIKit

/// One of `GameScene`'s 9 invisible, tappable per-cell hit targets — exercises per-node touch
/// dispatch rather than a single scene-level touch handler with manual hit-testing, per
/// `docs/GAME_DESIGN.md`'s "Presentation" section.
final class CellNode: SKShapeNode {
    let cellIndex: Int
    var onTap: ((Int) -> Void)?

    init(cellIndex: Int) {
        self.cellIndex = cellIndex
        super.init()
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTap?(cellIndex)
    }
}

/// A tappable rectangular button with a centered label — shared by `MenuScene`'s difficulty
/// options and `GameScene`'s New Game button.
final class ButtonNode: SKShapeNode {
    var onTap: (() -> Void)?

    init(size: CGSize, cornerRadius: CGFloat, label: String, fontSize: CGFloat) {
        super.init()
        isUserInteractionEnabled = true
        path = CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        strokeColor = .white
        lineWidth = 4
        fillColor = .clear

        let text = SKLabelNode(text: label)
        text.fontSize = fontSize
        text.fontColor = .white
        text.verticalAlignmentMode = .center
        addChild(text)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTap?()
    }
}
