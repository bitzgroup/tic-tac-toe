import SpriteKit
import XCTest

/// Records Apple's node-search syntax — `childNode(withName:)`, `subscript(_:)`,
/// `enumerateChildNodes(withName:using:)` and `SKAction.run(_:onChildWithName:)` — which
/// bitzgroup/SpriteKit mirrors.
///
/// Every test searches this tree:
///
///     root
///     ├── a
///     │   ├── b
///     │   │   └── c
///     │   └── b2
///     ├── bb
///     │   └── b
///     └── ab
final class SKNodeSearchParityTests: XCTestCase {
    private var root: SKNode!
    private var a: SKNode!
    private var b: SKNode!

    private func node(_ name: String, _ children: [SKNode] = []) -> SKNode {
        let node = SKNode()
        node.name = name
        children.forEach(node.addChild)
        return node
    }

    override func setUp() {
        super.setUp()
        root = node("root", [node("a", [node("b", [node("c")]), node("b2")]), node("bb", [node("b")]), node("ab")])
        a = root.children[0]
        b = a.children[0]
    }

    private func names(_ nodes: [SKNode]) -> [String] {
        nodes.map { $0.name ?? "" }
    }

    private func enumerated(_ from: SKNode, _ query: String) -> [String] {
        var found: [String] = []
        from.enumerateChildNodes(withName: query) { node, _ in found.append(node.name ?? "") }
        return found
    }

    func testAPlainNameMatchesDirectChildrenOnly() {
        XCTAssertNil(root.childNode(withName: "b"))
        XCTAssertEqual(names(a["b"]), ["b"])
        XCTAssertEqual(enumerated(root, "b"), [])
    }

    func testWildcardsAndCharacterClassesMatchWholeNames() {
        XCTAssertEqual(names(root["*"]), ["a", "bb", "ab"])
        XCTAssertEqual(names(root["b*"]), ["bb"])
        XCTAssertEqual(names(root["[ab]"]), ["a"])
        XCTAssertEqual(names(root["[a-b]*"]), ["a", "bb", "ab"])
        XCTAssertEqual(names(a["b*"]), ["b", "b2"])
    }

    func testSlashSeparatesPathStepsFromTheSearchingNode() {
        XCTAssertEqual(names(root["a/b"]), ["b"])
        XCTAssertEqual(names(root["a/*"]), ["b", "b2"])
        XCTAssertEqual(names(root["*/b"]), ["b", "b"])
        XCTAssertEqual(root.childNode(withName: "*/b"), b)
        XCTAssertEqual(names(root["a//c"]), ["c"])
    }

    func testDotIsTheNodeItselfAndDotDotItsParent() {
        XCTAssertEqual(a.childNode(withName: "."), a)
        XCTAssertEqual(a.childNode(withName: ".."), root)
        XCTAssertEqual(a.childNode(withName: "./b"), b)
        XCTAssertEqual(names(b["../b2"]), ["b2"])
        XCTAssertEqual(names(root["a/../bb"]), ["bb"])
    }

    func testALeadingSlashSearchesFromTheTreesRootWhoseOwnNameIsNotMatched() {
        XCTAssertEqual(b.childNode(withName: "/a"), a)
        XCTAssertEqual(names(b["/a/b"]), ["b"])
        XCTAssertNil(b.childNode(withName: "/root"))
        XCTAssertNil(b.childNode(withName: "//root"))
        let orphan = node("orphan", [node("x")])
        XCTAssertEqual(orphan.childNode(withName: "/x")?.name, "x")
    }

    func testALeadingDoubleSlashSearchesTheWholeTreeListingEachNodesChildrenBeforeDescending() {
        // Every node's children are listed, then each child is searched in turn — not a plain
        // depth-first preorder (which would be a, b, c, b2, bb, b, ab).
        XCTAssertEqual(names(b["//*"]), ["a", "bb", "ab", "b", "b2", "c", "b"])
        XCTAssertEqual(enumerated(b, "//*"), ["a", "bb", "ab", "b", "b2", "c", "b"])
        XCTAssertEqual(names(root["//b"]), ["b", "b"])
        XCTAssertEqual(root.childNode(withName: "//b"), b)
        XCTAssertEqual(names(root["//b/c"]), ["c"])
    }

    func testWildcardsMatchUnnamedNodes() {
        let parent = SKNode()
        parent.addChild(SKNode())
        XCTAssertEqual(parent["*"].count, 1)
        XCTAssertEqual(parent["//*"].count, 1)
        // An empty search string raises (crashes) — not recorded as a test.
    }

    func testABareSlashOrDoubleSlashMatchesNothing() {
        XCTAssertNil(root.childNode(withName: "/"))
        XCTAssertNil(root.childNode(withName: "//"))
    }

    func testEnumerationStopsWhenTheBlockSetsStop() {
        var seen: [String] = []
        root.enumerateChildNodes(withName: "//*") { node, stop in
            seen.append(node.name ?? "")
            if node.name == "b" { stop.pointee = true }
        }
        XCTAssertEqual(seen, ["a", "bb", "ab", "b"])
    }

    func testRunOnChildWithNameUsesTheSearchSyntaxAndRunsOnTheFirstMatchOnly() {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
        defer { window.isHidden = true }
        let scene = SKScene(size: view.bounds.size)
        scene.addChild(root)
        view.presentScene(scene)
        let otherB = root.children[1].children[0]

        let done = expectation(description: "actions ran")
        root.run(.sequence([
            .run(.moveBy(x: 3, y: 0, duration: 0), onChildWithName: "//b"),
            .run(.moveBy(x: 7, y: 0, duration: 0), onChildWithName: "b"),
            .wait(forDuration: 0.1),
            .run { done.fulfill() },
        ]))
        wait(for: [done], timeout: 2)

        XCTAssertEqual(b.position.x, 3)
        XCTAssertEqual(otherB.position.x, 0)
    }
}
