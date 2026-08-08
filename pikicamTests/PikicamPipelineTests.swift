import XCTest
import CoreImage
import UIKit
import Photos
@testable import pikicam

/// Runtime tests for pikicam's core pipeline.
///
/// These execute the real code paths inside the iOS simulator:
/// 1. CaptureService fails **cleanly** without a Bayer sensor (simulator has none).
/// 2. DevelopService zero-processes a real iPhone DNG into a viewable JPEG.
/// 3. StorageService saves the DNG + print pair to the Photos library.
///
/// The DNG fixture lives in `pikicamTests/Fixtures/` (git-ignored because of size).
/// Tests that require it are skipped when the fixture is absent, so a fresh clone
/// still runs the fixture-independent checks.
final class PikicamPipelineTests: XCTestCase {

    // MARK: - Capture

    func testCaptureFailsCleanlyWithoutBayerSensor() async {
        let service = CaptureService()

        do {
            _ = try await service.capturePhoto()
            XCTFail("Capture should not succeed on a simulator (no Bayer sensor).")
        } catch let error as CaptureError {
            XCTAssertEqual(error, .noBayerFormatAvailable,
                           "Expected the explicit no-Bayer error, got \(error)")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Develop

    func testZeroDevelopProducesViewableJPEGFromRealDNG() async throws {
        guard let dngData = try loadDNGFixture() else {
            throw XCTSkip("DNG fixture missing — copy one into pikicamTests/Fixtures/ or run on a device.")
        }

        let service = DevelopService()
        let result = try await service.develop(dngData: dngData, mode: .zero)

        XCTAssertFalse(result.jpegData.isEmpty, "Developed JPEG data must not be empty.")

        guard let decoded = CIImage(data: result.jpegData) else {
            XCTFail("Developed JPEG did not decode through Core Image.")
            return
        }

        // A real iPhone 12 Pro DNG develops to a full-resolution (> 1000px) image.
        XCTAssertGreaterThan(decoded.extent.width, 1000,  "Unexpected width: \(decoded.extent.width)")
        XCTAssertGreaterThan(decoded.extent.height, 1000, "Unexpected height: \(decoded.extent.height)")

        // The zero recipe must NOT produce a blank/black frame.
        let rendered = renderIntoBitmap(decoded)
        XCTAssertGreaterThan(averageLuminance(of: rendered), 5.0,
                             "Zero-process frame appears black.")
    }

    // MARK: - Storage

    func testStorageSavesDNGPlusPrintPairToPhotos() async throws {
        guard let rawData = try loadDNGFixture() else {
            throw XCTSkip("DNG fixture missing — copy one into pikicamTests/Fixtures/ or run on a device.")
        }

        let jpeg = makeSolidJPEG(width: 64, height: 64)
        let service = StorageService()
        let identifier: String
        do {
            identifier = try await service.savePair(processedData: jpeg, rawData: rawData)
        } catch StorageServiceError.saveFailed(let underlying) {
            let nsError = underlying as NSError
            if nsError.domain == "PHPhotosErrorDomain" && nsError.code == 3300 {
                throw XCTSkip("This iOS Simulator's Photos library rejects assets with a RAW companion "
                              + "(PHPhotosErrorChangeNotSupported / 3300). Real devices support .alternatePhoto.")
            }
            throw StorageServiceError.saveFailed(underlying: underlying)
        }

        XCTAssertFalse(identifier.isEmpty, "Photos should return a non-empty asset identifier.")

        // The asset must exist with the DNG as a companion resource.
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        XCTAssertEqual(fetch.count, 1, "Created asset should exist in the library.")

        if let asset = fetch.firstObject {
            let resources = PHAssetResource.assetResources(for: asset)
            XCTAssertTrue(resources.contains { $0.type == .alternatePhoto },
                          "DNG companion should be stored as an alternate (RAW) resource.")
        }
    }

    // MARK: - Helpers

    private func loadDNGFixture() throws -> Data? {
        guard let url = Bundle(for: Self.self).url(forResource: "IMG_1361", withExtension: "DNG") else {
            return nil
        }
        return try Data(contentsOf: url)
    }

    private func makeSolidJPEG(width: Int, height: Int) -> Data {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.systemRed.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }

    /// Renders a CIImage into an 8-bit RGBA bitmap.
    private func renderIntoBitmap(_ image: CIImage) -> [UInt8] {
        let context = CIContext()
        let extent = image.extent.integral
        guard let cgImage = context.createCGImage(image, from: extent),
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return []
        }
        return Array(UnsafeBufferPointer(start: bytes, count: CFDataGetLength(data)))
    }

    private func averageLuminance(of rgba: [UInt8]) -> Double {
        guard rgba.count >= 4 else { return 0 }
        var sum: UInt64 = 0
        var count: UInt64 = 0
        var i = 0
        while i + 3 < rgba.count {
            let r = Double(rgba[i]), g = Double(rgba[i + 1]), b = Double(rgba[i + 2])
            sum += UInt64(0.2126 * r + 0.7152 * g + 0.0722 * b)
            count += 1
            i += 4
        }
        return count == 0 ? 0 : Double(sum) / Double(count)
    }
}