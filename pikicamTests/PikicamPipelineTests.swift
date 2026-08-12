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
        let (printID, rawID): (String, String?)
        do {
            (printID, rawID) = try await service.savePair(processedData: jpeg, rawData: rawData)
        } catch StorageServiceError.insufficientPermissions(let status) {
            throw XCTSkip("No Photos write access in this environment (status \(status.rawValue)) — "
                          + "grant it on the simulator with "
                          + "`xcrun simctl privacy booted grant photos piki.pikicam`, or run the "
                          + "device UI walkthrough first so the permission flow grants access.")
        } catch StorageServiceError.saveFailed(let underlying) {
            let nsError = underlying as NSError
            if nsError.domain == "PHPhotosErrorDomain" && nsError.code == 3300 {
                throw XCTSkip("This iOS Simulator's Photos library rejects RAW assets (PHPhotosErrorChangeNotSupported / 3300). "
                              + "Real devices save RAW via independent .photo resources.")
            }
            throw StorageServiceError.saveFailed(underlying: underlying)
        }

        XCTAssertFalse(printID.isEmpty, "Print asset identifier should be non-empty.")
        if let rawID {
            XCTAssertFalse(rawID.isEmpty, "RAW asset identifier should be non-empty.")
            let rawAsset = PHAsset.fetchAssets(withLocalIdentifiers: [rawID], options: nil)
            XCTAssertEqual(rawAsset.count, 1, "Created RAW asset should exist.")
            if let rawObj = rawAsset.firstObject {
                let resources = PHAssetResource.assetResources(for: rawObj)
                XCTAssertTrue(
                    resources.contains { $0.type == .photo },
                    "DNG should be stored as an independent `.photo` resource (iOS 26.6 rejects `.alternatePhoto`)."
                )
            }
        }

        let printAsset = PHAsset.fetchAssets(withLocalIdentifiers: [printID], options: nil)
        XCTAssertEqual(printAsset.count, 1, "Created print asset should exist.")

        if let printObj = printAsset.firstObject {
            let resources = PHAssetResource.assetResources(for: printObj)
            XCTAssertTrue(
                resources.contains { $0.type == .photo },
                "Print should be stored as a `.photo` resource."
            )
        }
        if let rawObj = PHAsset.fetchAssets(withLocalIdentifiers: [rawID ?? ""], options: nil).firstObject {
            if let id = rawID, !id.isEmpty {
                let resources = PHAssetResource.assetResources(for: rawObj)
                XCTAssertTrue(
                    resources.contains { $0.type == .photo },
                    "DNG should be stored as an independent `.photo` resource (iOS 26.6 rejects `.alternatePhoto`)."
                )
            }
        }
    }

    // MARK: - Device end-to-end verification

    /// Device-only: after the UI walkthrough performed a real capture, the
    /// Photos library contains a recent developed-print asset (`.photo`) and
    /// a recent DNG negative asset (`.photo`) — two independent assets, since
    /// iOS 26.6's change API rejects `.alternatePhoto` pairing (3300).
    func testDevicePhotosLibraryContainsCapturedDNGPrintPair() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Device-only: simulator Photos rejects RAW assets (3300).")
        #else
        let readWrite = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard readWrite == .authorized || readWrite == .limited else {
            throw XCTSkip("Host app has no Photos read access (status \(readWrite.rawValue)) — "
                          + "run pikicamUITests on the device first so the permission flow grants access.")
        }
        let tenMinutesAgo = Date().addingTimeInterval(-600)
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 30
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        var foundPrint = false
        var foundDNG = false
        assets.enumerateObjects { asset, _, stop in
            guard let creation = asset.creationDate, creation > tenMinutesAgo else { return }
            let resources = PHAssetResource.assetResources(for: asset)
            let printLike = resources.contains {
                $0.type == .photo
                    && ($0.originalFilename.hasSuffix(".jpg")
                        || $0.originalFilename.hasSuffix(".jpeg")
                        || $0.originalFilename.hasSuffix(".heic"))
            }
            let dngLike = resources.contains {
                $0.type == .photo && $0.originalFilename.hasSuffix(".dng")
            }
            if printLike { foundPrint = true }
            if dngLike { foundDNG = true }
            if foundPrint && foundDNG { stop.pointee = true }
        }
        XCTAssertTrue(foundPrint, "No developed print asset in last 10 minutes.")
        XCTAssertTrue(foundDNG, "No DNG negative asset in last 10 minutes.")
        #endif
    }

    // MARK: - On-device Photos save probe (diagnostic)

    /// Diagnostic (device-only): the production save of the RAW+print pair
    /// fails with `PHPhotosErrorChangeNotSupported` (3300) on physical
    /// hardware — the same error the simulator was known to produce. This
    /// probe writes each candidate resource layout through the real change
    /// API and prints what this iOS build accepts, so the storage layer can
    /// be fixed to match. It creates a small number of clearly-named test
    /// assets in the library (PikicamProbe-*); delete them via Photos.app.
    func testDeviceProbePhotosSaveResourceVariants() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Device-only probe.")
        #else
        guard let dng = try loadDNGFixture() else {
            throw XCTSkip("DNG fixture missing — cannot probe pairing layouts.")
        }
        let jpeg = makeSolidJPEG(width: 256, height: 256)
        let variants: [(name: String, resources: [(PHAssetResourceType, Data, String?, String)])] = [
            ("jpeg-only(.photo)", [
                (.photo, jpeg, "public.jpeg", "jpg"),
            ]),
            ("dng-only(.photo, explicit UTI)", [
                (.photo, dng, "com.adobe.raw-image", "dng"),
            ]),
            ("dng-only(.photo, no UTI)", [
                (.photo, dng, nil, "dng"),
            ]),
            ("standard-pair(.photo jpeg + .alternatePhoto dng, explicit UTI)", [
                (.photo, jpeg, "public.jpeg", "jpg"),
                (.alternatePhoto, dng, "com.adobe.raw-image", "dng"),
            ]),
            ("reverse-pair(.photo dng + .alternatePhoto jpeg)", [
                (.photo, dng, "com.adobe.raw-image", "dng"),
                (.alternatePhoto, jpeg, "public.jpeg", "jpg"),
            ]),
            ("pair-without-explicit-dng-UTI", [
                (.photo, jpeg, "public.jpeg", "jpg"),
                (.alternatePhoto, dng, nil, "dng"),
            ]),
        ]

        for variant in variants {
            let outcome = try await probeSaveVariant(named: variant.name, resources: variant.resources)
            print("🖼️ PROBE \(variant.name) → \(outcome)")
        }

        // Cleanup: with full access the host app can delete the probe assets
        // it just created (impossible under add-only authorization).
        let allAssets = PHAsset.fetchAssets(with: .image, options: nil)
        var probes: [PHAsset] = []
        allAssets.enumerateObjects { asset, _, _ in
            if asset.localIdentifier.contains("PikicamProbe-") { probes.append(asset) }
        }
        if !probes.isEmpty {
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.deleteAssets(probes as NSArray)
                    } completionHandler: { _, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
                print("🧹 PROBE cleanup: deleted \(probes.count) PikicamProbe-* asset(s)")
            } catch {
                print("🧹 PROBE cleanup failed (add-only authorization?): \(error)")
            }
        }
        #endif
    }

    /// Attempts one PHAssetCreationRequest with the given resources and
    /// reports success (and the resulting resource layout) or the full
    /// error detail.
    private func probeSaveVariant(
        named name: String,
        resources: [(type: PHAssetResourceType, data: Data, uti: String?, ext: String)]
    ) async throws -> String {
        let identifier = "PikicamProbe-\(UUID().uuidString.prefix(8))"
        let result: Result<String, Error> = await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                for (index, resource) in resources.enumerated() {
                    let options = PHAssetResourceCreationOptions()
                    options.originalFilename = "\(identifier)-\(index).\(resource.ext)"
                    if let uti = resource.uti { options.uniformTypeIdentifier = uti }
                    request.addResource(with: resource.type, data: resource.data, options: options)
                }
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(identifier))
                }
            }
        }

        switch result {
        case .success(let localID):
            let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil)
            guard let asset = fetch.firstObject else {
                return "created but NOT fetchable (id \(localID))"
            }
            let stored = PHAssetResource.assetResources(for: asset)
                .map { "\($0.type.rawValue):\($0.originalFilename)" }
                .joined(separator: ", ")
            return "OK ✅ asset \(localID) resources [\(stored)]"
        case .failure(let error):
            let ns = error as NSError
            let detail = ns.userInfo
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: " | ")
            return "FAIL ❌ \(ns.domain) \(ns.code) — \(detail)"
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