import SpriteKit
import XCTest

/// Records Apple's multi-line `SKLabelNode` layout — `numberOfLines`, `preferredMaxLayoutWidth`,
/// `lineBreakMode` — which bitzgroup/SpriteKit mirrors. Exact glyph metrics are font- and
/// platform-specific, so these record the layout rules rather than pixel sizes.
final class SKLabelMultilineParityTests: XCTestCase {
    private let longText = "Hello world this is long"

    private func label(_ text: String) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica"
        label.fontSize = 20
        return label
    }

    func testDefaultsAreOneLineNoWidthLimitAndTruncatingTail() {
        let label = label(longText)
        XCTAssertEqual(label.numberOfLines, 1)
        XCTAssertEqual(label.preferredMaxLayoutWidth, 0)
        XCTAssertEqual(label.lineBreakMode, .byTruncatingTail)
    }

    func testOneLineIgnoresTheWidthLimitAndLineBreakMode() {
        let label = label(longText)
        let unlimited = label.frame
        label.preferredMaxLayoutWidth = 80
        XCTAssertEqual(label.frame, unlimited)
        label.lineBreakMode = .byWordWrapping
        XCTAssertEqual(label.frame, unlimited)
        label.lineBreakMode = .byClipping
        XCTAssertEqual(label.frame, unlimited)
    }

    func testOneLineDrawsANewlineInPlaceRatherThanBreaking() {
        let single = label("Hello")
        let withNewline = label("Hello\nworld")
        XCTAssertEqual(withNewline.frame.height, single.frame.height)
        XCTAssertGreaterThan(withNewline.frame.width, single.frame.width)
    }

    func testZeroLinesWrapsAtTheWidthLimitAndBreaksAtNewlines() {
        let label = label(longText)
        let oneLine = label.frame
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = 80
        XCTAssertLessThanOrEqual(label.frame.width, 80)
        XCTAssertGreaterThan(label.frame.height, oneLine.height * 3)

        let broken = self.label("Hello\nworld")
        let oneLineHeight = broken.frame.height
        broken.numberOfLines = 0
        XCTAssertGreaterThan(broken.frame.height, oneLineHeight * 2)
        XCTAssertLessThan(broken.frame.width, self.label("Hello world").frame.width)
    }

    func testALineCountAboveOneCapsTheWrappedLines() {
        let label = label(longText)
        label.preferredMaxLayoutWidth = 80
        label.numberOfLines = 0
        let all = label.frame.height
        label.numberOfLines = 2
        XCTAssertLessThan(label.frame.height, all)
        XCTAssertLessThanOrEqual(label.frame.width, 80)
    }

    func testMultiLineBaselineAlignmentBehavesLikeBottom() {
        let label = label("Hello\nworld")
        label.numberOfLines = 0
        label.verticalAlignmentMode = .baseline
        XCTAssertEqual(label.frame.minY, 0)
        label.verticalAlignmentMode = .bottom
        XCTAssertEqual(label.frame.minY, 0)
        let height = label.frame.height
        label.verticalAlignmentMode = .center
        XCTAssertEqual(label.frame.midY, 0, accuracy: 0.5)
        label.verticalAlignmentMode = .top
        XCTAssertEqual(label.frame.maxY, 0, accuracy: 0.5)
        XCTAssertEqual(label.frame.height, height)
    }

    func testMultiLineHorizontalAlignmentPlacesTheWholeBlock() {
        let label = label("Hi\nworld!!")
        label.numberOfLines = 0
        label.horizontalAlignmentMode = .left
        XCTAssertEqual(label.frame.minX, 0)
        label.horizontalAlignmentMode = .right
        XCTAssertEqual(label.frame.maxX, 0)
        label.horizontalAlignmentMode = .center
        XCTAssertEqual(label.frame.midX, 0, accuracy: 0.5)
    }
}
