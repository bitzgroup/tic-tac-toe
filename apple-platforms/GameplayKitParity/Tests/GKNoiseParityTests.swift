import GameplayKit
import XCTest

/// Records Apple's `GKNoise` value range, selection constructors and value remapping — what
/// bitzgroup/GameplayKit's `PARITY_GAP_PLAN.md` G6/G7 mirror. Constant sources make every value
/// position-independent, so each case is exact.
///
/// Not recordable as tests, because they crash the test process:
/// - `remapValues(toCurveWithControlPoints:)` raises `-[__NSCFNumber length]: unrecognized
///   selector` for any dictionary (numeric keys, string keys or string values alike).
/// - The four-argument selection initializer with empty `componentBoundaries` traps with "Array
///   index out of range": it needs `componentNoises.count - 1` boundaries.
final class GKNoiseParityTests: XCTestCase {
    private func constant(_ value: Double) -> GKNoise { GKNoise(GKConstantNoiseSource(value: value)) }

    private func value(_ noise: GKNoise) -> Float { noise.value(atPosition: vector_float2(0, 0)) }

    private func selected(_ components: [Double], by selection: Double, boundaries: [Double]? = nil,
                          blend: [Double]? = nil) -> Float {
        let noises = components.map(constant)
        guard let boundaries else {
            return value(GKNoise(componentNoises: noises, selectionNoise: constant(selection)))
        }
        let blendDistances = blend ?? Array(repeating: 0.0, count: boundaries.count)
        return value(GKNoise(
            componentNoises: noises, selectionNoise: constant(selection),
            componentBoundaries: boundaries.map(NSNumber.init(value:)),
            boundaryBlendDistances: blendDistances.map(NSNumber.init(value:)),
        ))
    }

    // MARK: - Value range

    func testSampledValuesAreClampedToMinusOneThroughOne() {
        XCTAssertEqual(value(constant(3)), 1)
        XCTAssertEqual(value(constant(-3)), -1)
        XCTAssertEqual(value(constant(-0.3)), -0.3, accuracy: 1e-6)
        let inverted = constant(3)
        inverted.invert()
        XCTAssertEqual(value(inverted), -1)
    }

    func testIntermediateResultsAreNotClamped() {
        let sum = constant(3)
        sum.add(constant(-2.5))
        XCTAssertEqual(value(sum), 0.5, accuracy: 1e-6)
        let product = constant(3)
        product.multiply(constant(0.5))
        XCTAssertEqual(value(product), 1)
    }

    func testNoiseMapsAreClampedToo() {
        let sum = constant(3)
        sum.add(constant(-2.5))
        let map = { (noise: GKNoise) in
            GKNoiseMap(noise, size: vector_double2(1, 1), origin: vector_double2(0, 0),
                       sampleCount: vector_int2(2, 2), seamless: false).value(at: vector_int2(0, 0))
        }
        XCTAssertEqual(map(constant(3)), 1)
        XCTAssertEqual(map(sum), 0.5, accuracy: 1e-6)
    }

    // MARK: - Selection (G6)

    func testASingleComponentIsPassedThrough() {
        XCTAssertEqual(selected([-0.8], by: -0.5), -0.8, accuracy: 1e-6)
        XCTAssertEqual(selected([0.8], by: 0.5), 0.8, accuracy: 1e-6)
    }

    /// Each component's -1...1 range is squeezed linearly into its own band of the selection
    /// axis: with the default boundary at 0, the first component lands in -1...0, the second in
    /// 0...1 (`lo + (v + 1) / 2 * (hi - lo)`).
    func testTwoComponentsAreRemappedIntoTheirHalfOfTheRange() {
        XCTAssertEqual(selected([-0.8, 0.4], by: -0.5), -0.9, accuracy: 1e-6)
        XCTAssertEqual(selected([0.0, 0.4], by: -0.5), -0.5, accuracy: 1e-6)
        XCTAssertEqual(selected([0.8, 0.4], by: -0.5), -0.1, accuracy: 1e-6)
        XCTAssertEqual(selected([0.4, -0.8], by: 0.5), 0.1, accuracy: 1e-6)
        XCTAssertEqual(selected([0.4, 0.0], by: 0.5), 0.5, accuracy: 1e-6)
        XCTAssertEqual(selected([0.4, 0.8], by: 0.5), 0.9, accuracy: 1e-6)
    }

    func testASelectionValueOnTheBoundaryPicksTheUpperComponent() {
        XCTAssertEqual(selected([-0.8, 0.8], by: -0.01), -0.9, accuracy: 1e-6)
        XCTAssertEqual(selected([-0.8, 0.8], by: 0.0), 0.9, accuracy: 1e-6)
        XCTAssertEqual(selected([-0.8, 0.8], by: 0.5, boundaries: [0.5]), 0.95, accuracy: 1e-6)
    }

    /// Default boundaries split -1...1 evenly: at ±1/3 for three components.
    func testDefaultBoundariesAreEvenlySpaced() {
        let components = [-0.8, 0.2, 0.8]
        XCTAssertEqual(selected(components, by: -0.34), -0.933333, accuracy: 1e-5)
        XCTAssertEqual(selected(components, by: -0.33), 0.066667, accuracy: 1e-5)
        XCTAssertEqual(selected(components, by: 0.33), 0.066667, accuracy: 1e-5)
        XCTAssertEqual(selected(components, by: 0.34), 0.933333, accuracy: 1e-5)
    }

    func testExplicitBoundariesSetTheBands() {
        XCTAssertEqual(selected([-0.8, 0.8], by: -0.9, boundaries: [-0.5]), -0.95, accuracy: 1e-6)
        XCTAssertEqual(selected([0.0, 0.0], by: 0.9, boundaries: [-0.5]), 0.25, accuracy: 1e-6)
        XCTAssertEqual(selected([0.0, 0.0], by: -0.9, boundaries: [0.5]), -0.25, accuracy: 1e-6)
        XCTAssertEqual(selected([0.8, -0.8], by: 0.9, boundaries: [0.5]), 0.55, accuracy: 1e-6)
        let three = [-0.8, 0.2, 0.8]
        XCTAssertEqual(selected(three, by: -0.6, boundaries: [-0.5, 0.5]), -0.95, accuracy: 1e-6)
        XCTAssertEqual(selected(three, by: 0.0, boundaries: [-0.5, 0.5]), 0.1, accuracy: 1e-6)
        XCTAssertEqual(selected(three, by: 0.6, boundaries: [-0.5, 0.5]), 0.95, accuracy: 1e-6)
    }

    func testBoundaryBlendDistancesHaveNoEffect() {
        for distance in [0.2, 0.5, 1.0, 2.0] {
            for selection in [-0.6, -0.1, -0.05] {
                XCTAssertEqual(selected([0.0, 0.0], by: selection, boundaries: [0], blend: [distance]), -0.5, accuracy: 1e-6)
            }
            for selection in [0.0, 0.05, 0.1, 0.6] {
                XCTAssertEqual(selected([0.0, 0.0], by: selection, boundaries: [0], blend: [distance]), 0.5, accuracy: 1e-6)
            }
        }
    }

    func testTheSelectedComponentIsUnclampedBeforeRemapping() {
        // (3 + 1) / 2 * 1 - 1 = 1, clamped only when sampled.
        XCTAssertEqual(selected([3, 3], by: -0.5), 1)
        XCTAssertEqual(selected([-0.5, 3], by: 0.5), 1)
    }

    // MARK: - Terraces (G7)

    /// What `remapValues(toTerracesWithPeaks:terracesInverted:)` returns today. It does not follow a
    /// terrace curve (flat near each peak, steep between them), isn't monotonic, and ignores
    /// `terracesInverted` for these peaks, so bitzgroup/GameplayKit implements the documented
    /// terrace shape instead; this records Apple's output in case it changes.
    func testTerracesDoNotFollowATerraceCurve() {
        func terraced(_ x: Double, _ peaks: [NSNumber], inverted: Bool = false) -> Float {
            let noise = constant(x)
            noise.remapValues(toTerracesWithPeaks: peaks, terracesInverted: inverted)
            return value(noise)
        }
        for inverted in [false, true] {
            XCTAssertEqual(terraced(-1, [-1, 1], inverted: inverted), -1)
            XCTAssertEqual(terraced(-0.5, [-1, 1], inverted: inverted), 1)
            XCTAssertEqual(terraced(-0.5, [-1, 0, 1], inverted: inverted), -0.5, accuracy: 1e-6)
            XCTAssertEqual(terraced(0, [-1, 0, 1], inverted: inverted), 1)
        }
        XCTAssertEqual(terraced(-1, [-1, -0.5, 0, 0.5, 1]), -1)
        XCTAssertEqual(terraced(-0.9, [-1, -0.5, 0, 0.5, 1]), 0.35, accuracy: 1e-6)
        XCTAssertEqual(terraced(-0.5, [-1, -0.5, 0, 0.5, 1]), -0.25, accuracy: 1e-6)
        XCTAssertEqual(terraced(0, [-1, -0.5, 0, 0.5, 1]), -0.125, accuracy: 1e-6)
        XCTAssertEqual(terraced(0.5, [-1, -0.5, 0, 0.5, 1]), 1)
        XCTAssertEqual(terraced(-0.9, [-1, -0.5, 0, 0.5, 1], inverted: true), -0.7, accuracy: 1e-6)
        XCTAssertEqual(terraced(0, [-1, -0.5, 0, 0.5, 1], inverted: true), 0.25, accuracy: 1e-6)
    }
}
