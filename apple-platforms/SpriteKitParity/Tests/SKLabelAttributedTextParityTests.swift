import SpriteKit
import XCTest

/// Records Apple's `SKLabelNode.attributedText`, which bitzgroup/SpriteKit (PARITY_GAP_PLAN.md L3)
/// mirrors with Android spans. Sizes are compared between labels rather than asserted, since glyph
/// metrics are font- and platform-specific; pixel tests render with `SKView.texture(from:)` and
/// count opaque pixels by color.
final class SKLabelAttributedTextParityTests: XCTestCase {
    private let helvetica20: [NSAttributedString.Key: Any] = [
        .font: UIFont(name: "Helvetica", size: 20)!, .foregroundColor: UIColor.red,
    ]

    private func plain(_ text: String, font: String = "Helvetica", size: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = font
        label.fontSize = size
        return label
    }

    func testAttributedTextIsNilByDefaultAndLeavesTextAndFontAlone() {
        let label = SKLabelNode(text: "Plain")
        XCTAssertNil(label.attributedText)
        label.attributedText = NSAttributedString(string: "Hello", attributes: helvetica20)
        XCTAssertEqual(label.attributedText?.string, "Hello")
        XCTAssertEqual(label.text, "Plain")
        XCTAssertEqual(label.fontSize, 32)
        XCTAssertNil(SKLabelNode(attributedText: NSAttributedString(string: "Hello")).text)
    }

    /// While `attributedText` is set, it alone is drawn and sized: changing `text` or the font
    /// changes nothing, and setting `text` doesn't clear it. Setting it to `nil` brings `text` back.
    func testAttributedTextOverridesTextAndFontUntilCleared() {
        let label = SKLabelNode(text: "Plain")
        label.attributedText = NSAttributedString(string: "Hello", attributes: helvetica20)
        let attributed = label.frame
        XCTAssertEqual(attributed.size, plain("Hello", size: 20).frame.size)
        label.text = "Other other other"
        label.fontSize = 60
        label.fontName = "Courier"
        XCTAssertNotNil(label.attributedText)
        XCTAssertEqual(label.frame, attributed)
        label.attributedText = nil
        XCTAssertEqual(label.frame.size, plain("Other other other", font: "Courier", size: 60).frame.size)
    }

    /// Even an empty attributed string replaces the text.
    func testAnEmptyAttributedStringStillReplacesTheText() {
        let label = plain("Plain", size: 20)
        label.attributedText = NSAttributedString(string: "")
        XCTAssertLessThan(label.frame.width, 3)
    }

    /// Text without font attributes is laid out in an `NSAttributedString`'s default font,
    /// 12-point Helvetica — not the label's font.
    func testUnattributedTextUsesTwelvePointHelvetica() {
        let label = SKLabelNode(attributedText: NSAttributedString(string: "Hello"))
        XCTAssertEqual(label.frame.size, plain("Hello", size: 12).frame.size)
    }

    /// Ranges can have their own fonts: a larger second letter makes the label taller.
    func testRangesKeepTheirOwnFonts() {
        let mixed = NSMutableAttributedString(string: "AB", attributes: [.font: UIFont(name: "Helvetica", size: 20)!])
        mixed.addAttribute(.font, value: UIFont(name: "Helvetica", size: 40)!, range: NSRange(location: 1, length: 1))
        XCTAssertGreaterThan(SKLabelNode(attributedText: mixed).frame.height, plain("AB", size: 20).frame.height * 1.5)
    }

    func testMultiLineSettingsAndAlignmentApply() {
        let label = SKLabelNode(attributedText: NSAttributedString(string: "Hello\nworld", attributes: helvetica20))
        let oneLine = label.frame
        XCTAssertEqual(oneLine.height, plain("Hello", size: 20).frame.height)
        label.numberOfLines = 0
        XCTAssertGreaterThan(label.frame.height, oneLine.height * 2)
        XCTAssertLessThan(label.frame.width, oneLine.width)

        let aligned = SKLabelNode(attributedText: NSAttributedString(string: "Hello", attributes: helvetica20))
        aligned.horizontalAlignmentMode = .left
        aligned.verticalAlignmentMode = .top
        XCTAssertEqual(aligned.frame.minX, 0)
        XCTAssertEqual(aligned.frame.maxY, 0)
    }

    // MARK: - Colors

    private func opaqueColors(_ node: SKLabelNode) -> Set<[UInt8]> {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
        defer { window.isHidden = true }
        let scene = SKScene(size: view.bounds.size)
        view.presentScene(scene)
        scene.addChild(node)
        let image = view.texture(from: node)!.cgImage()
        var p = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = CGContext(
            data: &p, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Set(stride(from: 0, to: p.count, by: 4).filter { p[$0 + 3] == 255 }.map { Array(p[$0..<$0 + 3]) })
    }

    /// The foreground color attribute colors the text, and the label's `fontColor` doesn't change it.
    func testForegroundColorWinsOverFontColor() {
        let label = SKLabelNode(attributedText: NSAttributedString(string: "HHH", attributes: helvetica20))
        label.fontColor = .green
        XCTAssertEqual(opaqueColors(label), [[255, 0, 0]])
    }

    /// Without a color attribute the text is black, an `NSAttributedString`'s default — not the
    /// label's white `fontColor`.
    func testUncoloredTextIsBlack() {
        let label = SKLabelNode(attributedText: NSAttributedString(string: "HHH", attributes: [.font: UIFont(name: "Helvetica", size: 20)!]))
        XCTAssertEqual(opaqueColors(label), [[0, 0, 0]])
    }

    /// `color`/`colorBlendFactor` still tint attributed text.
    func testColorStillTints() {
        let label = SKLabelNode(attributedText: NSAttributedString(
            string: "HHH", attributes: [.font: UIFont(name: "Helvetica", size: 20)!, .foregroundColor: UIColor.white]
        ))
        label.color = .blue
        label.colorBlendFactor = 1
        XCTAssertEqual(opaqueColors(label), [[0, 0, 255]])
    }
}
