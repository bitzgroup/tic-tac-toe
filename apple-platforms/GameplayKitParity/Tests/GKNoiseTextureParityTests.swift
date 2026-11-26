import GameplayKit
import SpriteKit
import XCTest

/// Records `SKTexture(noiseMap:)`, for bitzgroup/GKSKBridge's `SKTexture(noiseMap)`.
final class GKNoiseTextureParityTests: XCTestCase {
    /// The texture's pixels as RGBA bytes, row by row from the top.
    private func pixels(_ texture: SKTexture) -> (width: Int, height: Int, rgba: [UInt8]) {
        let image = texture.cgImage()
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (width, height, data)
    }

    /// The red channel of every pixel, top row first, after checking each pixel is opaque gray.
    private func grays(_ texture: SKTexture, file: StaticString = #filePath, line: UInt = #line) -> [UInt8] {
        let (_, _, rgba) = pixels(texture)
        return stride(from: 0, to: rgba.count, by: 4).map { i in
            XCTAssertEqual(rgba[i], rgba[i + 1], file: file, line: line)
            XCTAssertEqual(rgba[i], rgba[i + 2], file: file, line: line)
            XCTAssertEqual(rgba[i + 3], 255, file: file, line: line)
            return rgba[i]
        }
    }

    /// A two-row map whose rows are `bottom(x)` (row 0) and `top(x)` (row 1).
    private func map(columns: Int32, noise: GKNoise = GKNoise(GKConstantNoiseSource(value: 0)), _ rows: (Int) -> (bottom: Float, top: Float)) -> GKNoiseMap {
        let map = GKNoiseMap(noise, size: vector_double2(1, 1), origin: vector_double2(0, 0), sampleCount: vector_int2(columns, 2), seamless: false)
        for x in 0..<Int(columns) {
            let (bottom, top) = rows(x)
            map.setValue(bottom, at: vector_int2(Int32(x), 0))
            map.setValue(top, at: vector_int2(Int32(x), 1))
        }
        return map
    }

    /// One pixel per sample, row 0 at the bottom, gray from black at -1 to white at 1; filtered
    /// linearly.
    func testValuesBecomeGrayWithRowZeroAtTheBottom() {
        let texture = SKTexture(noiseMap: map(columns: 9) { x in let v = Float(x) / 4 - 1; return (v, -v) })

        XCTAssertEqual(texture.size(), CGSize(width: 9, height: 2))
        XCTAssertEqual(texture.filteringMode, .linear)
        XCTAssertEqual(grays(texture), [255, 223, 191, 159, 127, 95, 63, 31, 0] + [0, 31, 63, 95, 127, 159, 191, 223, 255])
    }

    /// The gray is `(v + 1) / 2 × 255` rounded down, in double precision: -0.2 as a `Float` gives
    /// 101 (float arithmetic would give 102).
    func testGrayIsRoundedDownInDoublePrecision() {
        let texture = SKTexture(noiseMap: map(columns: 11) { x in let v = Float(x) / 50; return (v, -v) })

        XCTAssertEqual(grays(texture), [127, 124, 122, 119, 117, 114, 112, 109, 107, 104, 101] + [127, 130, 132, 135, 137, 140, 142, 145, 147, 150, 153])
    }

    /// Values outside -1...1 are clamped.
    func testValuesOutsideTheRangeAreClamped() {
        let values: [Float] = [-3, -1.5, 1.5, 3]
        let texture = SKTexture(noiseMap: map(columns: 4) { x in (values[x], values[x]) })

        XCTAssertEqual(grays(texture), [0, 0, 255, 255, 0, 0, 255, 255])
    }

    /// The noise's gradient colors color the texture (bitzgroup/GameplayKit's `GKNoise` has none).
    func testGradientColorsColorTheTexture() {
        let noise = GKNoise(GKConstantNoiseSource(value: 0), gradientColors: [-1: .red, 1: .blue])
        let texture = SKTexture(noiseMap: map(columns: 5, noise: noise) { x in let v = Float(x) / 2 - 1; return (v, v) })

        let rgba = pixels(texture).rgba
        let row: [[UInt8]] = stride(from: 0, to: 5 * 4, by: 4).map { (i: Int) -> [UInt8] in Array(rgba[i..<(i + 4)]) }
        let expected: [[UInt8]] = [[255, 0, 0, 255], [191, 0, 63, 255], [127, 0, 127, 255], [63, 0, 191, 255], [0, 0, 255, 255]]
        XCTAssertEqual(row, expected)
    }
}
