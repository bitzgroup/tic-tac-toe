import GameplayKit
import XCTest

/// Records how Apple's GameplayKit random distributions behave where the documentation is silent,
/// so bitzgroup/GameplayKit can mirror it. See docs/ARCHITECTURE.md's "Parity probes" section.
final class GKRandomParityTests: XCTestCase {
    private func histogram(_ count: Int, _ draw: () -> Int) -> [Int: Int] {
        var result: [Int: Int] = [:]
        for _ in 0..<count { result[draw(), default: 0] += 1 }
        return result
    }

    /// `nextInt(upperBound:)` draws uniformly from `lowestValue...min(highestValue, upperBound - 1)`.
    /// It does not cap `nextInt()` (which would pile the excess onto the top value).
    func testNextIntUpperBoundIsUniformOverTheClippedRange() {
        let dist = GKRandomDistribution(randomSource: GKMersenneTwisterRandomSource(seed: 7), lowestValue: 1, highestValue: 6)
        let counts = histogram(60_000) { dist.nextInt(upperBound: 3) }
        XCTAssertEqual(Set(counts.keys), [1, 2])
        for value in [1, 2] { XCTAssertEqual(Double(counts[value]!) / 60_000, 0.5, accuracy: 0.02) }
    }

    func testNextIntUpperBoundAboveTheRangeIsPlainNextInt() {
        let dist = GKRandomDistribution(randomSource: GKMersenneTwisterRandomSource(seed: 7), lowestValue: 1, highestValue: 6)
        let counts = histogram(60_000) { dist.nextInt(upperBound: 10) }
        XCTAssertEqual(Set(counts.keys), Set(1...6))
    }

    func testNextIntUpperBoundJustAboveLowestValueAlwaysReturnsLowestValue() {
        let dist = GKRandomDistribution(randomSource: GKMersenneTwisterRandomSource(seed: 7), lowestValue: 1, highestValue: 6)
        XCTAssertEqual(Set(histogram(1_000) { dist.nextInt(upperBound: 2) }.keys), [1])
    }

    /// The draw is exactly `lowestValue + source.nextInt(upperBound: clippedCount)`.
    func testNextIntUpperBoundDrawsStraightFromTheSource() {
        let dist = GKRandomDistribution(randomSource: GKMersenneTwisterRandomSource(seed: 11), lowestValue: 1, highestValue: 6)
        let source = GKMersenneTwisterRandomSource(seed: 11)
        XCTAssertEqual((0..<50).map { _ in dist.nextInt(upperBound: 3) }, (0..<50).map { _ in source.nextInt(upperBound: 2) + 1 })
    }

    /// Subclasses don't change it: a Gaussian distribution's `nextInt(upperBound:)` is uniform too.
    func testGaussianNextIntUpperBoundIsUniform() {
        let dist = GKGaussianDistribution(randomSource: GKMersenneTwisterRandomSource(seed: 5), lowestValue: 1, highestValue: 9)
        let counts = histogram(60_000) { dist.nextInt(upperBound: 5) }
        XCTAssertEqual(Set(counts.keys), [1, 2, 3, 4])
        for value in 1...4 { XCTAssertEqual(Double(counts[value]!) / 60_000, 0.25, accuracy: 0.02) }
    }

    /// A shuffled distribution's `nextInt(upperBound:)` draws from the source too, without taking
    /// a value out of the shuffled bag.
    func testShuffledNextIntUpperBoundLeavesTheBagAlone() {
        let dist = GKShuffledDistribution(randomSource: GKMersenneTwisterRandomSource(seed: 11), lowestValue: 1, highestValue: 6)
        var bagDraws: [Int] = []
        for i in 0..<18 {
            if i % 3 == 2 { _ = dist.nextInt(upperBound: 4) } else { bagDraws.append(dist.nextInt()) }
        }
        XCTAssertEqual(Set(bagDraws.prefix(6)), Set(1...6))
        XCTAssertEqual(Set(bagDraws.suffix(6)), Set(1...6))
    }

    /// Every run of `highestValue - lowestValue + 1` draws is a permutation, and the first value of
    /// a new run never repeats the last value of the previous one.
    func testShuffledNeverRepeatsAcrossTheWrapAround() {
        for high in [2, 3, 6] {
            let dist = GKShuffledDistribution(randomSource: GKMersenneTwisterRandomSource(seed: 9), lowestValue: 1, highestValue: high)
            let values = (0..<(high * 2_000)).map { _ in dist.nextInt() }
            for start in stride(from: 0, to: values.count, by: high) {
                XCTAssertEqual(Set(values[start..<start + high]), Set(1...high))
            }
            for i in 1..<values.count { XCTAssertNotEqual(values[i], values[i - 1], "1...\(high) at \(i)") }
        }
    }
}
