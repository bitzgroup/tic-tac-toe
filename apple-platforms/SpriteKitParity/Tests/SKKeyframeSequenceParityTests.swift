import SpriteKit
import XCTest

/// Records how `SKKeyframeSequence` samples, loops and edits its keyframes — bitzgroup/SpriteKit
/// (PARITY_GAP_PLAN.md E2) mirrors it.
///
/// `sample(atTime:)` holds the first keyframe's value up to its time and the last keyframe's
/// value from its time on. Between them it finds the first keyframe whose time is greater than
/// the sample time, then holds the keyframe before it (`.step`), interpolates straight to it
/// (`.linear`, the default), or follows a cubic Hermite curve (`.spline`). `.loop` wraps the time
/// into `0 ..< lastTime`. Times are never sorted, not by the initializer and not by the editing
/// methods.
final class SKKeyframeSequenceParityTests: XCTestCase {
    private func sequence(
        _ values: [Double],
        _ times: [Double],
        mode: SKInterpolationMode = .linear,
        repeat repeatMode: SKRepeatMode = .clamp
    ) -> SKKeyframeSequence {
        let sequence = SKKeyframeSequence(
            keyframeValues: values.map { NSNumber(value: $0) },
            times: times.map { NSNumber(value: $0) }
        )
        sequence.interpolationMode = mode
        sequence.repeatMode = repeatMode
        return sequence
    }

    private func value(_ sequence: SKKeyframeSequence, at time: Double) -> Double? {
        (sequence.sample(atTime: CGFloat(time)) as? NSNumber)?.doubleValue
    }

    private func assertSamples(
        _ sequence: SKKeyframeSequence,
        _ expected: [(time: Double, value: Double)],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for (time, value) in expected {
            guard let actual = self.value(sequence, at: time) else {
                XCTFail("no value at \(time)", file: file, line: line)
                continue
            }
            XCTAssertEqual(actual, value, accuracy: 0.0001, "at \(time)", file: file, line: line)
        }
    }

    private func keyframes(_ sequence: SKKeyframeSequence) -> [String] {
        (0..<sequence.count()).map {
            let value = (sequence.getKeyframeValue(for: $0) as? NSNumber)?.doubleValue ?? .nan
            return "\(sequence.getKeyframeTime(for: $0))=\(value)"
        }
    }

    /// The `.spline` curve: a cubic Hermite segment between each pair of keyframes, in the
    /// segment's own `0...1` parameter. A tangent is 0 at the first and last keyframe; at any
    /// other keyframe it is the change to the next keyframe and the change from the previous one,
    /// each weighted by the *other* side's time gap, `(Δprev · gapNext + Δnext · gapPrev) /
    /// (gapPrev + gapNext)` — uniform spacing gives Catmull-Rom's `(next − prev) / 2`. The same
    /// tangent is used on both sides of the keyframe, whatever the two segments' lengths.
    private func splineModel(_ values: [Double], _ times: [Double], at time: Double) -> Double {
        let last = values.count - 1
        if time <= times[0] { return values[0] }
        if time >= times[last] { return values[last] }
        let upper = times.firstIndex { $0 > time }!
        let lower = upper - 1
        func tangent(_ i: Int) -> Double {
            if i == 0 || i == last { return 0 }
            let gapPrev = times[i] - times[i - 1]
            let gapNext = times[i + 1] - times[i]
            let deltaPrev = values[i] - values[i - 1]
            let deltaNext = values[i + 1] - values[i]
            return (deltaPrev * gapNext + deltaNext * gapPrev) / (gapPrev + gapNext)
        }
        let u = (time - times[lower]) / (times[upper] - times[lower])
        let u2 = u * u
        let u3 = u2 * u
        return (2 * u3 - 3 * u2 + 1) * values[lower] + (u3 - 2 * u2 + u) * tangent(lower) +
            (-2 * u3 + 3 * u2) * values[upper] + (u3 - u2) * tangent(upper)
    }

    func testDefaultsAreLinearAndClamp() {
        let sequence = sequence([0, 10], [0, 1])
        XCTAssertEqual(sequence.interpolationMode, .linear)
        XCTAssertEqual(sequence.repeatMode, .clamp)
        XCTAssertEqual(sequence.count(), 2)
    }

    func testAnEmptySequenceSamplesNil() {
        let sequence = SKKeyframeSequence(capacity: 4)
        XCTAssertEqual(sequence.count(), 0)
        XCTAssertNil(sequence.sample(atTime: 0.5))
    }

    func testASingleKeyframeIsItsValueEverywhere() {
        for mode: SKInterpolationMode in [.linear, .spline, .step] {
            for repeatMode: SKRepeatMode in [.clamp, .loop] {
                let sequence = sequence([5], [0.5], mode: mode, repeat: repeatMode)
                assertSamples(sequence, [(0, 5), (0.5, 5), (1, 5), (2, 5)])
            }
        }
    }

    func testLinearInterpolatesAndHoldsTheEndValues() {
        let sequence = sequence([0, 10, 0, 40], [0.2, 0.4, 0.6, 1.0])
        assertSamples(sequence, [
            (-1.5, 0), (0, 0), (0.2, 0), (0.25, 2.5), (0.3, 5), (0.4, 10), (0.45, 7.5),
            (0.6, 0), (0.7, 10), (0.9, 30), (1.0, 40), (1.5, 40), (3.7, 40),
        ])
    }

    func testStepHoldsTheLatestKeyframeReached() {
        let sequence = sequence([0, 10, 0, 40], [0.2, 0.4, 0.6, 1.0], mode: .step)
        assertSamples(sequence, [
            (-0.5, 0), (0.35, 0), (0.4, 10), (0.55, 10), (0.6, 0), (0.9, 0), (1.0, 40), (2.0, 40),
        ])
    }

    func testSplineIsAHermiteCurveWithWeightedTangents() {
        let cases: [(values: [Double], times: [Double])] = [
            ([0, 10], [0, 1]),
            ([0, 1, 3, 6], [0, 1, 2, 3]),
            ([0, 10, 0, 40], [0.2, 0.4, 0.6, 1.0]),
            ([0, 10, 0], [0, 0.1, 1]),
        ]
        for (values, times) in cases {
            let sequence = sequence(values, times, mode: .spline)
            let start = times.first! - 0.5
            let end = times.last! + 0.5
            for step in 0...100 {
                let time = start + (end - start) * Double(step) / 100
                XCTAssertEqual(
                    value(sequence, at: time)!, splineModel(values, times, at: time), accuracy: 0.0001,
                    "\(values) at \(times), time \(time)"
                )
            }
        }
        // Two keyframes give a smoothstep; an unevenly spaced keyframe overshoots on its longer side.
        assertSamples(sequence([0, 10], [0, 1], mode: .spline), [(0.1, 0.28), (0.5, 5)])
        assertSamples(sequence([0, 10, 0], [0, 0.1, 1], mode: .spline), [(0.05, 4), (0.2, 10.359397)])
        assertSamples(sequence([0, 10, 0, 40], [0.2, 0.4, 0.6, 1.0], mode: .spline), [
            (0.5, 4.166667), (0.575, -0.208333), (0.8, 20.833333),
        ])
    }

    func testLoopWrapsTheTimeByTheLastKeyframeTime() {
        // The period is the last keyframe's time (1.0), not the span from the first (0.8): before
        // the first keyframe, each pass holds its value.
        let values: [Double] = [0, 10, 0, 40]
        let times = [0.2, 0.4, 0.6, 1.0]
        assertSamples(sequence(values, times, repeat: .loop), [
            (-1.5, 5), (-0.5, 5), (-0.1, 30), (1.0, 0), (1.1, 0), (1.3, 5), (1.8, 20), (2.0, 0), (3.7, 10),
        ])
        assertSamples(sequence(values, times, mode: .step, repeat: .loop), [
            (1.0, 0), (1.5, 10), (1.8, 0),
        ])
        assertSamples(sequence(values, times, mode: .spline, repeat: .loop), [
            (-0.1, 34.062496), (1.5, 4.166668), (1.8, 20.833334),
        ])
        assertSamples(sequence([0, 1, 3, 6], [0, 1, 2, 3], mode: .spline, repeat: .loop), [
            (-1, 3), (-0.5, 4.8125), (3.5, 0.3125), (4, 1), (6.25, 0.085938),
        ])
    }

    func testTimesAreNotSorted() {
        // Clamping limits the time to the *last* keyframe's time (0.5), and the search then stops
        // at the first keyframe after it (1.0), so 0.5 and later all land halfway to it.
        let unsorted = sequence([0, 10, 20], [0, 1, 0.5])
        XCTAssertEqual(keyframes(unsorted), ["0.0=0.0", "1.0=10.0", "0.5=20.0"])
        assertSamples(unsorted, [(0.25, 2.5), (0.5, 5), (0.75, 5), (1, 5)])

        // With the first keyframe's time the largest, every time up to it holds the first value.
        let reversed = sequence([0, 10, 5], [2, 1, 0.5])
        assertSamples(reversed, [(0, 0), (0.5, 0), (1, 0), (2, 0)])
    }

    func testEqualTimesTakeTheLaterKeyframe() {
        let sequence = sequence([0, 10, 20], [0, 0.5, 0.5])
        assertSamples(sequence, [(0.25, 5), (0.49, 9.8), (0.5, 20), (0.75, 20)])
    }

    func testEditingKeepsTheKeyframesInTheirOrder() {
        let sequence = sequence([0, 10], [0, 1])
        sequence.addKeyframeValue(NSNumber(value: 5.0), time: 0.5)
        XCTAssertEqual(keyframes(sequence), ["0.0=0.0", "1.0=10.0", "0.5=5.0"])
        assertSamples(sequence, [(0.25, 2.5), (0.5, 5), (0.75, 5)])

        sequence.setKeyframeTime(2, for: 0)
        XCTAssertEqual(keyframes(sequence), ["2.0=0.0", "1.0=10.0", "0.5=5.0"])

        sequence.setKeyframeValue(NSNumber(value: 100.0), for: 1)
        sequence.setKeyframeValue(NSNumber(value: 7.0), time: 0.1, for: 2)
        XCTAssertEqual(keyframes(sequence), ["2.0=0.0", "1.0=100.0", "0.1=7.0"])

        sequence.removeKeyframe(at: 0)
        XCTAssertEqual(keyframes(sequence), ["1.0=100.0", "0.1=7.0"])
        sequence.removeLastKeyframe()
        XCTAssertEqual(keyframes(sequence), ["1.0=100.0"])
        sequence.removeLastKeyframe()
        XCTAssertEqual(sequence.count(), 0)
        XCTAssertNil(sequence.sample(atTime: 0))
        sequence.removeLastKeyframe()
        XCTAssertEqual(sequence.count(), 0)
    }

    private func rgba(_ value: Any?) -> [CGFloat]? {
        guard let color = value as? SKColor else { return nil }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha]
    }

    private func assertRGBA(
        _ actual: [CGFloat]?,
        _ expected: [CGFloat],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else { return XCTFail("not a color", file: file, line: line) }
        for (a, e) in zip(actual, expected) {
            XCTAssertEqual(a, e, accuracy: 0.0001, "\(actual)", file: file, line: line)
        }
    }

    func testColorsInterpolateEachUnpremultipliedComponent() {
        let colors = SKKeyframeSequence(
            keyframeValues: [SKColor.red, SKColor(red: 0, green: 0, blue: 1, alpha: 0)],
            times: [0, 1]
        )
        assertRGBA(rgba(colors.sample(atTime: 0.25)), [0.75, 0, 0.25, 0.75])
        assertRGBA(rgba(colors.sample(atTime: 0.5)), [0.5, 0, 0.5, 0.5])
        colors.interpolationMode = .spline
        assertRGBA(rgba(colors.sample(atTime: 0.25)), [0.84375, 0, 0.15625, 0.84375])

        let whiteToRed = SKKeyframeSequence(keyframeValues: [SKColor(white: 1, alpha: 1), SKColor.red], times: [0, 1])
        assertRGBA(rgba(whiteToRed.sample(atTime: 0.5)), [1, 0.5, 0.5, 1])
    }

    func testOnlyNumbersAndColorsAreSampled() {
        let integers = SKKeyframeSequence(keyframeValues: [NSNumber(value: 0), NSNumber(value: 3)], times: [0, 1])
        XCTAssertEqual((integers.sample(atTime: 0.5) as? NSNumber)?.doubleValue, 1.5)

        let points = SKKeyframeSequence(
            keyframeValues: [NSValue(cgPoint: .zero), NSValue(cgPoint: CGPoint(x: 10, y: 20))],
            times: [0, 1]
        )
        XCTAssertNil(points.sample(atTime: 0.5))
        let strings = SKKeyframeSequence(keyframeValues: ["a", "b"], times: [0, 1])
        XCTAssertNil(strings.sample(atTime: 0))
        XCTAssertNil(strings.sample(atTime: 0.5))
    }
}
