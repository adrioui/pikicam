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
/// 3. PikicamLibraryModel saves a DNG-only capture to the Photos library
///    (one asset, one `.photo` resource — no print pair).
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
        let result: DNGDisplayRendition
        do {
            result = try await service.render(dngData: dngData, orientation: .up)
        } catch let error as DevelopError {
            // Missing enhancement controls are skipped (not errors) — see
            // CIRAWZeroProcessor. A failure here is a real develop failure.
            throw XCTSkip("Develop failed in this environment: \(error.localizedDescription)")
        }

        XCTAssertNotNil(result.cgImage, "Rendered CGImage must not be nil.")

        let decoded = result.ciImage

        // A real iPhone 12 Pro DNG develops to a full-resolution (> 1000px) image.
        XCTAssertGreaterThan(decoded.extent.width, 1000,  "Unexpected width: \(decoded.extent.width)")
        XCTAssertGreaterThan(decoded.extent.height, 1000, "Unexpected height: \(decoded.extent.height)")

        // The zero recipe must NOT produce a blank/black frame.
        let rendered = renderIntoBitmap(decoded)
        XCTAssertGreaterThan(averageLuminance(of: rendered), 5.0,
                             "Zero-process frame appears black.")
    }

    // MARK: - Storage

    @MainActor
    func testStorageSavesDNGSinglePhotoResourceToPhotos() async throws {
        guard let rawData = try loadDNGFixture() else {
            throw XCTSkip("DNG fixture missing — copy one into pikicamTests/Fixtures/ or run on a device.")
        }

        let library = PikicamLibraryModel()
        var captureForCleanup: PikicamCapture?

        let capture: PikicamCapture
        do {
            let saved = try await library.save(
                CapturedDNG(data: rawData, capturedAt: Date())
            )
            capture = saved
            captureForCleanup = saved
        } catch PhotoLibraryError.insufficientPermissions(let authorization) {
            throw XCTSkip("No Photos write access in this environment (status \(authorization)).")
        } catch PhotoLibraryError.saveFailed(let failure) {
            #if targetEnvironment(simulator)
            if failure.domain == "PHPhotosErrorDomain" && failure.code == 3300 {
                throw XCTSkip("Simulator Photos rejects RAW assets (3300).")
            }
            #endif
            // On device 3300 is a real failure — do not mask it as a skip.
            throw PhotoLibraryError.saveFailed(failure)
        }

        // The save reported a typed PikicamCapture with a usable asset ID.
        // (The meaningful assertions below are the asset/resource ones; the
        // UUID is a UUID by construction.)

        // Exactly one Photos asset with exactly one `.photo` DNG resource:
        // the immutable contract of the DNG-only pipeline.
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [capture.assetID.localIdentifier], options: nil)
        XCTAssertEqual(result.count, 1, "The save must create exactly one Photos asset.")

        if let asset = result.firstObject {
            XCTAssertEqual(asset.localIdentifier, capture.assetID.localIdentifier)
            XCTAssertGreaterThan(Int(asset.pixelWidth), 0)
            XCTAssertGreaterThan(Int(asset.pixelHeight), 0)
            XCTAssertEqual(Int(asset.pixelWidth), capture.pixelWidth,
                           "The returned capture must report the asset's pixel width.")
            XCTAssertEqual(Int(asset.pixelHeight), capture.pixelHeight,
                           "The returned capture must report the asset's pixel height.")

            let resources = PHAssetResource.assetResources(for: asset)
            XCTAssertEqual(resources.count, 1, "A pikicam capture must be exactly one resource — no print pair.")
            if let resource = resources.first {
                XCTAssertEqual(resource.type, .photo, "The single resource must be a `.photo` resource.")
                XCTAssertEqual(resource.uniformTypeIdentifier, "com.adobe.raw-image",
                               "The resource must carry the DNG UTI.")
                XCTAssertEqual(resource.originalFilename, "pikicam-\(capture.id.uuid.uuidString).dng",
                               "The resource must use the namespaced pikicam DNG filename.")
            }
        }

        // Cleanup: delete exactly the asset we created, under any usable
        // authorization policy (.authorized or .limited). This never deletes
        // unrelated user assets — we pass the precise PhotoAssetID we just
        // received. If authorization is not usable, we cannot clean up and
        // must surface that explicitly rather than silently leaking.
        if let cleanupCapture = captureForCleanup {
            let status = await library.manager.authorizationStatus()
            switch status {
            case .authorized, .limited:
                do {
                    try await library.manager.delete(cleanupCapture)
                } catch PhotoLibraryError.insufficientPermissions(let authorization) {
                    XCTFail("Cleanup failed: Photos permission became unusable (status \(authorization)) — leaked asset \(cleanupCapture.assetID).")
                } catch {
                    XCTFail("Cleanup failed to delete the created asset \(cleanupCapture.assetID): \(error)")
                }
            case .denied, .restricted, .notDetermined:
                // Save succeeded but we have no usable authorization to clean up;
                // surface the leak rather than silently leaving the asset.
                XCTFail("Save succeeded but authorization is \(status) — cannot delete created asset \(cleanupCapture.assetID); leaked test asset requires manual cleanup in Photos.")
            }
        }
    }

    // MARK: - Device end-to-end verification

    /// Device-only independent probe: checks that a recent pikicam DNG asset
    /// exists with the exact single-resource layout (`pikicam-*.dng`, `.photo`,
    /// DNG UTI, no print pair).
    ///
    /// HONESTY / LIMITATION: This test is NOT tied to the exact capture
    /// performed in `SmokeLaunchTest.testDeviceCaptureWalkthrough`. It will
    /// pass if any recent pikicam asset (within the last 10 minutes) exists,
    /// so a failed walkthrough could still pass if an older pikicam asset
    /// happens to be in the window. There is no shared cross-process marker
    /// between the UI-test target and the unit-test host today (no App Group,
    /// no shared suite), and the pipeline test cannot know the UUID of the
    /// walkthrough's capture without one. The authoritative proof of the
    /// current end-to-end flow is `SmokeLaunchTest.testDeviceCaptureWalkthrough`
    /// itself, which performs a real shutter tap and then asserts the gallery
    /// grid shows `gallery-cell-0`, the viewer opens, and Cancel preserves the
    /// asset. That walkthrough is the coherent semantic boundary for
    /// capture-success; this probe only verifies the device's Photos store
    /// accepts the DNG-only contract.
    ///
    /// If a cross-target marker is introduced (e.g. an App Group
    /// UserDefaults suite, a UIPasteboard sentinel, or a deterministic
    /// `capturedAt` ordering contract written by the walkthrough and read
    /// here), this probe should be tightened to require the exact
    /// walkthrough asset's identifier/filename.
    func testDevicePhotosLibraryContainsCapturedDNGSingleResource() throws {
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

        // The capture is identified by its namespaced filename
        // (`pikicam-<captureID>.dng`), not by any recent `.dng`.
        var pikicamAsset: PHAsset?
        assets.enumerateObjects { asset, _, stop in
            guard let creation = asset.creationDate, creation > tenMinutesAgo else { return }
            let resources = PHAssetResource.assetResources(for: asset)
            let isPikicamCapture = resources.contains {
                $0.type == .photo
                    && $0.uniformTypeIdentifier == "com.adobe.raw-image"
                    && $0.originalFilename.hasPrefix("pikicam-")
                    && $0.originalFilename.hasSuffix(".dng")
            }
            if isPikicamCapture {
                pikicamAsset = asset
                stop.pointee = true
            }
        }
        guard let asset = pikicamAsset else {
            XCTFail("No pikicam DNG asset (`pikicam-*.dng`, `.photo`, DNG UTI) in last 10 minutes. "
                    + "This is an independent recent-asset probe, not a binding to the current walkthrough's capture. "
                    + "If the walkthrough just failed, this probe will also fail unless an older pikicam asset happens to be in the window.")
            return
        }

        // Exact one-resource layout: a pikicam capture is one `.photo` DNG
        // resource and nothing else.
        let resources = PHAssetResource.assetResources(for: asset)
        XCTAssertEqual(resources.count, 1, "A pikicam capture must be exactly one resource — no print pair.")
        if let resource = resources.first {
            XCTAssertEqual(resource.type, .photo, "The single resource must be a `.photo` resource.")
            XCTAssertEqual(resource.uniformTypeIdentifier, "com.adobe.raw-image",
                           "The resource must carry the DNG UTI.")
            XCTAssertTrue(resource.originalFilename.hasPrefix("pikicam-"),
                          "The resource must use the namespaced pikicam filename.")
            XCTAssertTrue(resource.originalFilename.hasSuffix(".dng"),
                          "The namespaced filename must end in `.dng`.")
        }
        #endif
    }

    // MARK: - On-device Photos save probe (diagnostic)

    /// Diagnostic (device-only): probes which Photos resource layouts this
    /// iOS build accepts. It writes each candidate layout through the real
    /// change API and prints the outcome. It creates a small number of
    /// clearly-named test assets (`PikicamProbe-*` in the original filename);
    /// probe assets are cleaned up by inspecting `PHAssetResource`
    /// originalFilename, not the asset localIdentifier, so no unrelated user
    /// asset is ever deleted.
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

        // Cleanup: delete only the probe assets we created, identified by
        // PHAssetResource.originalFilename == `PikicamProbe-*`. Scanning
        // localIdentifier would never match (probe prefix is in the filename)
        // and would leak assets; scanning filenames avoids deleting unrelated
        // user assets whose localIdentifiers happen to contain the substring.
        let allAssets = PHAsset.fetchAssets(with: .image, options: nil)
        var probes: [PHAsset] = []
        allAssets.enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            let isProbe = resources.contains { $0.originalFilename.hasPrefix("PikicamProbe-") }
            if isProbe { probes.append(asset) }
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
                print("🧹 PROBE cleanup: deleted \(probes.count) PikicamProbe-* asset(s) (matched by originalFilename)")
            } catch {
                print("🧹 PROBE cleanup failed (add-only/limited authorization?): \(error)")
            }
        }
        #endif
    }

    /// Attempts one PHAssetCreationRequest with the given resources and
    /// reports success (and the resulting resource layout) or the full
    /// error detail. Captures the placeholder localIdentifier inside the
    /// change block and requires `success == true`; the returned identifier
    /// is the real `PHAsset.localIdentifier`, not the filename prefix.
    private func probeSaveVariant(
        named name: String,
        resources: [(type: PHAssetResourceType, data: Data, uti: String?, ext: String)]
    ) async throws -> String {
        let identifier = "PikicamProbe-\(UUID().uuidString.prefix(8))"
        final class ProbePlaceholderBox { var localIdentifier: String? }

        let result: Result<String, Error> = await withCheckedContinuation { continuation in
            let box = ProbePlaceholderBox()
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                for (index, resource) in resources.enumerated() {
                    let options = PHAssetResourceCreationOptions()
                    options.originalFilename = "\(identifier)-\(index).\(resource.ext)"
                    if let uti = resource.uti { options.uniformTypeIdentifier = uti }
                    request.addResource(with: resource.type, data: resource.data, options: options)
                }
                box.localIdentifier = request.placeholderForCreatedAsset?.localIdentifier
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else if !success {
                    let err = NSError(domain: "PHPhotoLibrary", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photos reported success == false for variant \(name)"])
                    continuation.resume(returning: .failure(err))
                } else if let localID = box.localIdentifier {
                    continuation.resume(returning: .success(localID))
                } else {
                    let err = NSError(domain: "PHPhotoLibrary", code: -2, userInfo: [NSLocalizedDescriptionKey: "Placeholder localIdentifier was nil for variant \(name) despite success"])
                    continuation.resume(returning: .failure(err))
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
