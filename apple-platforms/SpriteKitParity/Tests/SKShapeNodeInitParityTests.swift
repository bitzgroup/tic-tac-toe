import SpriteKit
import XCTest

/// Records the paths Apple's remaining `SKShapeNode` convenience initializers build, which
/// bitzgroup/SpriteKit's companion factories mirror.
final class SKShapeNodeInitParityTests: XCTestCase {
    /// Each path element as "type:(x,y),...", CGPathElementType raw values (0 move, 1 line,
    /// 3 cubic curve, 4 close).
    private func elements(_ path: CGPath) -> [String] {
        var result: [String] = []
        path.applyWithBlock { element in
            let type = element.pointee.type
            let count: Int
            switch type {
            case .addCurveToPoint: count = 3
            case .addQuadCurveToPoint: count = 2
            case .closeSubpath: count = 0
            default: count = 1
            }
            let points = (0..<count).map { index -> String in
                let point = element.pointee.points[index]
                return String(format: "(%.3f,%.3f)", point.x, point.y)
            }
            result.append("\(type.rawValue):" + points.joined(separator: ","))
        }
        return result
    }

    func testRectAndEllipseInitializersUseTheRectAsGivenNotCentered() {
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
        XCTAssertEqual(SKShapeNode(rect: rect).path?.boundingBox, rect)
        XCTAssertEqual(SKShapeNode(rect: rect, cornerRadius: 5).path?.boundingBox, rect)
        XCTAssertEqual(SKShapeNode(ellipseIn: rect).path?.boundingBox, rect)
        XCTAssertEqual(SKShapeNode(rect: rect).position, .zero)
    }

    func testPathCenteredMovesThePathsBoundingBoxCenterToTheOrigin() {
        let path = CGPath(rect: CGRect(x: 10, y: 20, width: 30, height: 40), transform: nil)
        XCTAssertEqual(SKShapeNode(path: path, centered: true).path?.boundingBox, CGRect(x: -15, y: -20, width: 30, height: 40))
        XCTAssertEqual(SKShapeNode(path: path, centered: false).path?.boundingBox, CGRect(x: 10, y: 20, width: 30, height: 40))
    }

    /// An open polyline — whose first line segment runs from the first point to itself.
    func testPointsInitializerBuildsAnOpenPolyline() {
        var points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10)]
        let shape = SKShapeNode(points: &points, count: points.count)
        XCTAssertEqual(
            elements(shape.path!),
            ["0:(0.000,0.000)", "1:(0.000,0.000)", "1:(10.000,0.000)", "1:(10.000,10.000)"]
        )
    }

    /// A Catmull-Rom spline through every point, as cubic Béziers with control points a sixth of
    /// the neighbors' difference away (end points repeated past either end) — starting with a
    /// zero-length segment from the first point to itself.
    func testSplinePointsInitializerBuildsACatmullRomSplineThroughEveryPoint() {
        var points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10), CGPoint(x: 20, y: 0), CGPoint(x: 30, y: 10)]
        let shape = SKShapeNode(splinePoints: &points, count: points.count)
        XCTAssertEqual(elements(shape.path!), [
            "0:(0.000,0.000)",
            "3:(0.000,0.000),(-1.667,-1.667),(0.000,0.000)",
            "3:(1.667,1.667),(6.667,10.000),(10.000,10.000)",
            "3:(13.333,10.000),(16.667,0.000),(20.000,0.000)",
            "3:(23.333,0.000),(28.333,8.333),(30.000,10.000)",
        ])
    }
}
