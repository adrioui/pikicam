import CoreImage
import XCTest

@testable import pikicam

final class BNWDeveloperTests: XCTestCase {
    func testMonochromeHEICIsChannelNeutral() async throws {
        guard
            let url = Bundle(for: Self.self).url(forResource: "fixture-bayer-rich", withExtension: "dng"),
            let dng = try? Data(contentsOf: url)
        else {
            throw XCTSkip("fixture missing (documented skip class)")
        }
        let capture = CaptureResult(data: dng, isDNG: true, timestamp: Date())
        guard let heic = await BNWDeveloper.monochromeHEIC(from: capture) else {
            XCTFail("develop returned nil")
            return
        }
        let source = try XCTUnwrap(CGImageSourceCreateWithData(heic as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let width = 48
        let height = 36
        let space = CGColorSpace(name: CGColorSpace.displayP3)!
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        var worst = 0
        for offset in stride(from: 0, to: width * height * 4, by: 4) {
            let r = Int(pixels[offset])
            let g = Int(pixels[offset + 1])
            let b = Int(pixels[offset + 2])
            worst = max(worst, abs(r - g), abs(g - b))
        }
        XCTAssertLessThanOrEqual(worst, 2, "monochrome output must be channel-neutral")
    }
}
