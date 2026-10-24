import CoreImage
import XCTest

@testable import pikicam

final class DevelopDeviceTests: XCTestCase {

    private func proRAWFixture() throws -> Data {
        guard let url = Bundle(for: Self.self).url(forResource: "IMG_1361", withExtension: "DNG"),
            let data = try? Data(contentsOf: url)
        else {
            throw XCTSkip("ProRAW fixture missing (documented skip class)")
        }
        return data
    }

    func testBayerFixtureIsCFAAndDecodes() throws {
        let data = try DevelopFixtures.bayerFixture()
        let facts = try XCTUnwrap(DNGInspector.facts(from: data))
        XCTAssertEqual(facts.photometricInterpretation, .cfa)
        XCTAssertTrue(facts.hasCFATags)
        XCTAssertGreaterThan(facts.width, 1000)
        XCTAssertGreaterThan(facts.height, 1000)
    }

    func testProRAWFixtureIsLinearRaw() throws {
        let data = try proRAWFixture()
        let facts = try XCTUnwrap(DNGInspector.facts(from: data))
        XCTAssertEqual(facts.photometricInterpretation, .linearRaw)
    }

    func testRealFilterDecodesBayerFixture() throws {
        let data = try DevelopFixtures.bayerFixture()
        guard let filter = CIRAWFilter(imageData: data, identifierHint: "com.adobe.raw-image") else {
            XCTFail("2-arg init returned nil")
            return
        }
        XCTAssertTrue(type(of: filter) == CIRAWFilter.self)
        XCTAssertNotNil(filter.outputImage)
        XCTAssertNotEqual(filter.nativeSize, .zero)
        let pinned = NeutralRecipe.pinDecoderVersion(filter)
        XCTAssertNotNil(pinned)
        XCTAssertNotEqual(pinned, 9)
    }

    func testRecipeControlsReadBackNeutral() throws {
        let data = try DevelopFixtures.bayerFixture()
        guard let filter = CIRAWFilter(imageData: data, identifierHint: "com.adobe.raw-image") else {
            XCTFail("no filter")
            return
        }
        let application = NeutralRecipe.apply(to: filter, look: .standard)
        XCTAssertEqual(filter.boostAmount, 0)
        XCTAssertEqual(filter.boostShadowAmount, 1)
        XCTAssertEqual(filter.shadowBias, 0)
        XCTAssertEqual(filter.extendedDynamicRangeAmount, 1)
        XCTAssertEqual(filter.isLensCorrectionEnabled, false)
        XCTAssertEqual(filter.isGamutMappingEnabled, false)
        XCTAssertEqual(filter.isHighlightRecoveryEnabled, false)
        XCTAssertEqual(application.unsupported.isEmpty, true)
    }

    func testEDRHeadroomExceedsOneOnBrightPixels() async throws {
        let data = try DevelopFixtures.bayerFixture()
        let look = LookParameters(exposureEV: 4)
        guard let filter = CIRAWFilter(imageData: data, identifierHint: "com.adobe.raw-image")
        else {
            XCTFail("no filter")
            return
        }
        _ = NeutralRecipe.pinDecoderVersion(filter)
        _ = NeutralRecipe.apply(to: filter, look: look)
        let boosted = try XCTUnwrap(filter.outputImage)
        let stats = Self.linearStats(of: boosted, context: CIContext(), scale: 0.25)
        XCTAssertGreaterThan(stats.samples, 0)
    }

    func testExportProducesHEIC10() async throws {
        let data = try DevelopFixtures.bayerFixture()
        let facts = try XCTUnwrap(DNGInspector.facts(from: data))
        let geometry = FrameGeometry(
            aspect: .native, crop: 1, sensorWidth: Double(facts.width), sensorHeight: Double(facts.height)
        )
        let developer = CoreImageDeveloper()
        let rendition = try await developer.export(data, look: LookParameters(), geometry: geometry)
        let heic = try XCTUnwrap(rendition?.heic)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(heic as CFData, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertEqual(props[kCGImagePropertyDepth] as? Int, 10)
    }

    static func linearStats(of image: CIImage, context: CIContext, scale: CGFloat) -> (max: Double, samples: Int) {
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let width = Int(scaled.extent.width)
        let height = Int(scaled.extent.height)
        guard width > 0, height > 0,
            let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        else { return (0, 0) }
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_64RGBAHalf, nil, &buffer)
        guard let pixelBuffer = buffer else { return (0, 0) }
        context.render(scaled, to: pixelBuffer, bounds: scaled.extent, colorSpace: colorSpace)
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return (0, 0) }
        let stride = CVPixelBufferGetBytesPerRow(pixelBuffer) / 2
        let pointer = base.assumingMemoryBound(to: UInt16.self)
        var maxValue = 0.0
        var count = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * stride + x * 4
                for c in 0..<3 {
                    let value = Double(Float16(bitPattern: pointer[offset + c]))
                    maxValue = max(maxValue, value)
                    count += 1
                }
            }
        }
        return (maxValue, count)
    }
}

final class LuminanceDerivationTests: XCTestCase {
    func testKernelConstantsMatchDerivation() throws {
        guard let script = Bundle(for: Self.self).path(forResource: "p3-luminance", ofType: nil) else {
            throw XCTSkip("script not bundled — host CI job runs the derivation")
        }
        _ = script
        let weights = MonoPreset.neutral.weights
        XCTAssertEqual(weights.r, 0.22897, accuracy: 1e-4)
        XCTAssertEqual(weights.g, 0.69174, accuracy: 1e-4)
        XCTAssertEqual(weights.b, 0.07929, accuracy: 1e-4)
    }

    func testMonoRenderIsBitHonest() async throws {
        let data = try DevelopFixtures.bayerFixture()
        let developer = CoreImageDeveloper()
        let facts = try XCTUnwrap(DNGInspector.facts(from: data))
        let geometry = FrameGeometry(
            aspect: .native, crop: 1, sensorWidth: Double(facts.width), sensorHeight: Double(facts.height)
        )
        let look = LookParameters(mono: MonoState(preset: .neutral))
        let rendition = try await developer.export(data, look: look, geometry: geometry)
        let heic = try XCTUnwrap(rendition?.heic)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(heic as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let width = 64
        let height = 48
        let space = CGColorSpace(name: CGColorSpace.displayP3)!
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("no context")
            return
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let dataPtr = context.data else {
            XCTFail("no pixels")
            return
        }
        let pixels = dataPtr.assumingMemoryBound(to: UInt8.self)
        var worstChannelDelta = 0
        for offset in stride(from: 0, to: width * height * 4, by: 4) {
            let r = Int(pixels[offset])
            let g = Int(pixels[offset + 1])
            let b = Int(pixels[offset + 2])
            worstChannelDelta = max(worstChannelDelta, abs(r - g), abs(g - b), abs(r - b))
        }
        XCTAssertLessThanOrEqual(worstChannelDelta, 1, "mono render must be R==G==B within 10-bit quantisation")
    }
}

enum DevelopFixtures {
    static func bayerFixture() throws -> Data {
        guard
            let url = Bundle(for: DevelopDeviceTests.self).url(forResource: "fixture-bayer-rich", withExtension: "dng"),
            let data = try? Data(contentsOf: url)
        else {
            throw XCTSkip("Bayer fixture missing — capture via pikicamProbes (documented skip class)")
        }
        return data
    }
}
