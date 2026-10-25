import Photos
import XCTest

/// A test-only Photos fixture that looks like a real library: foreign
/// assets (HEIC images, videos, offloaded markers), legacy PIKI_ assets,
/// and fresh ones. Every archive/migration/save test runs against this.
@MainActor
enum SeededLibrary {
    struct Seeded {
        let localID: String
        let kind: Kind
        let filename: String

        enum Kind {
            case foreignHEIC
            case foreignVideo
            case legacyPIKIDNG
            case freshPIKI
        }
    }

    static var seeded: [Seeded] = []

    @discardableResult
    static func build(test: XCTestCase) async throws -> [Seeded] {
        teardown()
        var made: [Seeded] = []
        for spec in [("foreign-1", Seeded.Kind.foreignHEIC), ("foreign-2", Seeded.Kind.foreignVideo),
                     ("legacy-1", Seeded.Kind.legacyPIKIDNG), ("legacy-2", Seeded.Kind.legacyPIKIDNG),
                     ("fresh-1", Seeded.Kind.freshPIKI)] {
            let id = try await create(filename: spec.0, kind: spec.1)
            made.append(Seeded(localID: id, kind: spec.1, filename: spec.0))
        }
        seeded = made
        return made
    }

    private static func create(filename: String, kind: Kind) async throws -> String {
        let box = IDBox()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.creationDate = Date()
            let options = PHAssetResourceCreationOptions()
            switch kind {
            case .foreignHEIC:
                options.originalFilename = "IMG_\(filename).heic"
                request.addResource(with: .photo, data: Data(repeating: 0x11, count: 128), options: options)
            case .foreignVideo:
                options.originalFilename = "VID_\(filename).mov"
                request.addResource(with: .video, data: Data(repeating: 0x22, count: 128), options: options)
            case .legacyPIKIDNG:
                options.originalFilename = "PIKI_\(filename).dng"
                request.addResource(with: .photo, data: Data(repeating: 0x33, count: 128), options: options)
            case .freshPIKI:
                options.originalFilename = "PIKI_\(filename).heic"
                request.addResource(with: .photo, data: Data(repeating: 0x44, count: 128), options: options)
            }
            box.created = request.placeholderForCreatedAsset?.localIdentifier ?? ""
        } completionHandler: { _, error in
            if let error {
                box.failed = "\(error)"
            }
        }
        if let failed = box.failed {
            throw CocoaError(.coderInvalidValue, userInfo: [NSLocalizedDescriptionKey: failed])
        }
        return box.created
    }

    static func teardown() {
        let ids = seeded.map(\.localID)
        guard !ids.isEmpty else { return }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assets: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in assets.append(asset) }
        guard !assets.isEmpty else { return }
        let semaphore = DispatchSemaphore(value: 0)
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        } completionHandler: { _, _ in semaphore.signal() }
        semaphore.wait()
        seeded = []
    }
}

final class IDBox: @unchecked Sendable {
    var created = ""
    var failed: String?
}
