import GameplayKit
import XCTest

private final class Tag: NSObject {
    let n: Int
    init(_ n: Int) { self.n = n }
}

/// Records Apple's `GKRTree` query and removal behavior, which bitzgroup/GameplayKit's `GKRTree`
/// (PARITY_GAP_PLAN.md G2) mirrors.
final class GKRTreeParityTests: XCTestCase {
    private func v(_ x: Float, _ y: Float) -> vector_float2 { vector_float2(x, y) }

    private func query(_ tree: GKRTree<Tag>, _ min: vector_float2, _ max: vector_float2) -> [Int] {
        tree.elements(inBoundingRectMin: min, rectMax: max).map(\.n)
    }

    /// Twelve 1x1 elements in a row along x, 10 apart (element i at x = 10i...10i+1, y = 0...1).
    private func row(_ count: Int = 12, strategy: GKRTreeSplitStrategy = .linear) -> (GKRTree<Tag>, [Tag]) {
        let tree = GKRTree<Tag>(maxNumberOfChildren: 3)
        let tags = (0..<count).map { Tag($0) }
        for tag in tags {
            let x = Float(tag.n) * 10
            tree.addElement(tag, boundingRectMin: v(x, 0), boundingRectMax: v(x + 1, 1), splitStrategy: strategy)
        }
        return (tree, tags)
    }

    // MARK: - Queries

    /// Not an intersection test: only rects the query rect fully contains (edges included) come back.
    func testAQueryReturnsOnlyElementsWhoseRectsItFullyContains() {
        let tree = GKRTree<Tag>(maxNumberOfChildren: 3)
        tree.addElement(Tag(1), boundingRectMin: v(0, 0), boundingRectMax: v(2, 2), splitStrategy: .halve)
        XCTAssertEqual(query(tree, v(-1, -1), v(3, 3)), [1])
        XCTAssertEqual(query(tree, v(0, 0), v(2, 2)), [1])
        XCTAssertEqual(query(tree, v(1, 1), v(3, 3)), []) // overlaps half of it
        XCTAssertEqual(query(tree, v(0.5, 0.5), v(1, 1)), []) // inside it
        XCTAssertEqual(query(tree, v(1, 1), v(1, 1)), []) // a point inside it
        XCTAssertEqual(query(tree, v(2, 0), v(3, 2)), []) // shares an edge
        XCTAssertEqual(query(tree, v(-1, -1), v(3, 1)), []) // covers it in x only
    }

    func testAQueryDeepInALargerTreeAlsoReturnsOnlyFullyContainedElements() {
        let tree = GKRTree<Tag>(maxNumberOfChildren: 3)
        for i in 0..<30 {
            let x = Float(i % 6) * 10, y = Float(i / 6) * 10
            tree.addElement(Tag(i), boundingRectMin: v(x, y), boundingRectMax: v(x + 2, y + 2), splitStrategy: .quadratic)
        }
        XCTAssertEqual(Set(query(tree, v(-1, -1), v(100, 100))), Set(0..<30))
        // Elements 8, 13 and 14 overlap this rect but stick out of it.
        XCTAssertEqual(query(tree, v(9, 9), v(21, 21)), [7])
    }

    func testAnInvertedQueryRectReturnsNothing() {
        let (tree, _) = row()
        XCTAssertEqual(query(tree, v(200, 9), v(-9, -9)), [])
    }

    func testElementsThatFitInOneNodeComeBackInInsertionOrder() {
        let tree = GKRTree<Tag>(maxNumberOfChildren: 3)
        for n in [2, 0, 1] {
            let x = Float(n)
            tree.addElement(Tag(n), boundingRectMin: v(x, 0), boundingRectMax: v(x + 1, 1), splitStrategy: .halve)
        }
        XCTAssertEqual(query(tree, v(-9, -9), v(9, 9)), [2, 0, 1])
    }

    func testEverySplitStrategyKeepsEveryElementFindable() {
        for strategy in [GKRTreeSplitStrategy.halve, .linear, .quadratic, .reduceOverlap] {
            let (tree, _) = row(8, strategy: strategy)
            XCTAssertEqual(Set(query(tree, v(-9, -9), v(200, 9))), Set(0..<8), "\(strategy.rawValue)")
            XCTAssertEqual(Set(query(tree, v(15, -1), v(45, 2))), [2, 3, 4], "\(strategy.rawValue)")
        }
    }

    func testTwoChildrenPerNodeIsEnough() {
        // maxNumberOfChildren: 1 crashes on the second insert, so it isn't probed.
        let tree = GKRTree<Tag>(maxNumberOfChildren: 2)
        for n in 0..<4 {
            let x = Float(n)
            tree.addElement(Tag(n), boundingRectMin: v(x, 0), boundingRectMax: v(x + 1, 1), splitStrategy: .halve)
        }
        XCTAssertEqual(Set(query(tree, v(-9, -9), v(99, 9))), Set(0..<4))
    }

    func testQueryReserveDefaultsToOneAndDoesNotChangeResults() {
        let (tree, _) = row(5)
        XCTAssertEqual(tree.queryReserve, 1)
        let before = query(tree, v(-9, -9), v(200, 9))
        tree.queryReserve = 0
        XCTAssertEqual(query(tree, v(-9, -9), v(200, 9)), before)
        tree.queryReserve = 100
        XCTAssertEqual(query(tree, v(-9, -9), v(200, 9)), before)
    }

    // MARK: - Adding and removing

    func testTheSameElementCanBeAddedMoreThanOnce() {
        let tree = GKRTree<Tag>(maxNumberOfChildren: 3)
        let tag = Tag(3)
        tree.addElement(tag, boundingRectMin: v(0, 0), boundingRectMax: v(1, 1), splitStrategy: .halve)
        tree.addElement(tag, boundingRectMin: v(0, 0), boundingRectMax: v(1, 1), splitStrategy: .halve)
        tree.addElement(tag, boundingRectMin: v(5, 5), boundingRectMax: v(6, 6), splitStrategy: .halve)
        XCTAssertEqual(query(tree, v(-9, -9), v(9, 9)), [3, 3, 3])
        XCTAssertEqual(query(tree, v(-1, -1), v(2, 2)), [3, 3])
    }

    /// Within a node holding elements, the first record of the element goes, whatever rect it was
    /// added with and whatever rect is passed.
    func testRemovingTakesTheElementsFirstRecordInANodeWhateverItsRect() {
        let tree = GKRTree<Tag>(maxNumberOfChildren: 3)
        let tag = Tag(3)
        tree.addElement(tag, boundingRectMin: v(0, 0), boundingRectMax: v(1, 1), splitStrategy: .halve)
        tree.addElement(tag, boundingRectMin: v(5, 5), boundingRectMax: v(6, 6), splitStrategy: .halve)
        tree.removeElement(tag, boundingRectMin: v(5, 5), boundingRectMax: v(6, 6))
        XCTAssertEqual(query(tree, v(-1, -1), v(2, 2)), [])
        XCTAssertEqual(query(tree, v(4, 4), v(7, 7)), [3])

        let single = GKRTree<Tag>(maxNumberOfChildren: 3)
        let lone = Tag(5)
        single.addElement(lone, boundingRectMin: v(0, 0), boundingRectMax: v(1, 1), splitStrategy: .halve)
        single.removeElement(lone, boundingRectMin: v(50, 50), boundingRectMax: v(60, 60))
        XCTAssertEqual(query(single, v(-9, -9), v(9, 9)), [])
    }

    /// Below the root, removal only looks inside child nodes whose bounds fully contain the rect
    /// passed — so a rect inside the element's node finds it even if it misses the element, and the
    /// element's own rect plus a margin doesn't.
    func testRemovalOnlyDescendsIntoNodesWhoseBoundsContainTheRect() {
        let cases: [(String, vector_float2, vector_float2, Bool)] = [
            ("exact", v(0, 0), v(1, 1), true),
            ("inside the element", v(0.2, 0.2), v(0.8, 0.8), true),
            ("beside the element, inside its node", v(2, 0), v(3, 1), true),
            ("sticking out of the node in y", v(0.5, 0.5), v(5, 5), false),
            ("covering the whole tree", v(-1, -1), v(200, 2), false),
            ("in another node", v(110, 0), v(111, 1), false),
        ]
        for (label, min, max, removed) in cases {
            let (tree, tags) = row()
            tree.removeElement(tags[0], boundingRectMin: min, boundingRectMax: max)
            XCTAssertEqual(query(tree, v(-9, -9), v(200, 9)).contains(0), !removed, label)
            XCTAssertEqual(query(tree, v(-9, -9), v(200, 9)).count, removed ? 11 : 12, label)
        }
    }

    func testRemovingAnElementThatIsNotThereChangesNothing() {
        let (tree, _) = row()
        tree.removeElement(Tag(99), boundingRectMin: v(0, 0), boundingRectMax: v(200, 1))
        XCTAssertEqual(query(tree, v(-9, -9), v(200, 9)).count, 12)
        XCTAssertEqual(Set(query(tree, v(-9, -9), v(200, 9))), Set(0..<12))
    }
}
