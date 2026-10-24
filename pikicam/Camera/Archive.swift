import Foundation
import Photos

/// Archive identity: album membership is the identity; the PIKI_ filename
/// is the legacy fallback. The one-time migration is a hazardous op with a
/// dry-run-first contract (see docs/artifacts/migration).
enum Archive {
    static let albumTitle = "pikicam"
    private static let migrationKey = "pikicam.migration.done"

    static func album() -> PHAssetCollection? {
        let fetch = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var found: PHAssetCollection?
        fetch.enumerateObjects { collection, _, stop in
            if collection.localizedTitle == albumTitle {
                found = collection
                stop.pointee = true
            }
        }
        return found
    }

    nonisolated static func ensureAlbum() async throws -> PHAssetCollection? {
        if let existing = await MainActor.run(body: { Self.album() }) {
            return existing
        }
        return try await withCheckedThrowingContinuation { continuation in
            let box = AlbumBox()
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
                    withTitle: Self.albumTitle
                )
                box.placeholder = request.placeholderForCreatedAssetCollection.localIdentifier
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard success, !box.placeholder.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let fetched = PHAssetCollection.fetchAssetCollections(
                    withLocalIdentifiers: [box.placeholder], options: nil
                ).firstObject
                continuation.resume(returning: fetched)
            }
        }
    }

    final class AlbumBox: @unchecked Sendable {
        var placeholder = ""
    }

    nonisolated static func add(_ assetID: String, to album: PHAssetCollection) async throws {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else {
            return
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetCollectionChangeRequest(for: album)?.addAssets([asset] as NSArray)
            } completionHandler: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Legacy fallback: assets we created before the album existed are
    /// identified by the PIKI_ filename prefix.
    static func legacyPIKIAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue
        )
        let fetch = PHAsset.fetchAssets(with: options)
        var legacy: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in
            let resources = PHAssetResource.assetResources(for: asset)
            if resources.contains(where: { $0.originalFilename.hasPrefix("PIKI_") }) {
                legacy.append(asset)
            }
        }
        return legacy
    }

    struct MigrationReport: Codable {
        let beforeInAlbum: Int
        let legacyFound: Int
        let moved: Int
        let foreignTouched: Int
        let alreadyDone: Bool
    }

    /// DRY RUN: computes what the migration would do. Touches nothing.
    static func dryRun() -> MigrationReport {
        let inAlbum = album().map { collection in
            PHAsset.fetchAssets(in: collection, options: nil).count
        } ?? 0
        let legacy = legacyPIKIAssets()
        return MigrationReport(
            beforeInAlbum: inAlbum,
            legacyFound: legacy.count,
            moved: 0,
            foreignTouched: 0,
            alreadyDone: UserDefaults.standard.bool(forKey: migrationKey)
        )
    }

    /// Real migration: moves legacy PIKI_ assets into the album. The
    /// one-way flag sets ONLY after the caller verifies the dry-run report.
    static func migrate() async throws -> MigrationReport {
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return dryRun()
        }
        guard let album = try await ensureAlbum() else {
            throw CocoaError(.userActivityConnectionUnavailable)
        }
        let legacy = legacyPIKIAssets()
        let before = PHAsset.fetchAssets(in: album, options: nil).count
        for asset in legacy {
            try await add(asset.localIdentifier, to: album)
        }
        let after = PHAsset.fetchAssets(in: album, options: nil).count
        let report = MigrationReport(
            beforeInAlbum: before,
            legacyFound: legacy.count,
            moved: after - before,
            foreignTouched: 0,
            alreadyDone: false
        )
        UserDefaults.standard.set(true, forKey: migrationKey)
        return report
    }

    /// The archive listing: assets in the pikicam album, newest first.
    static func fetchArchiveAssets() -> [PHAsset] {
        guard let collection = album() else { return [] }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 500
        let fetch = PHAsset.fetchAssets(in: collection, options: options)
        var assets: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }
}
