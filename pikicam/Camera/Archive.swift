import Foundation
import Photos

/// Archive identity: album membership is the identity; the PIKI_ filename
/// is the legacy fallback. The one-time migration is a hazardous op with a
/// dry-run-first contract. The legacy scan is BOUNDED (assets created
/// after first launch, fetchLimit 200) and runs OFF the main actor — the
/// archive never blocks or crashes on library size (regression: the
/// whole-library main-thread scan crashed the archive, three crash logs).
enum Archive {
    static let albumTitle = "pikicam"
    private static let migrationKey = "pikicam.migration.done"
    private static let firstLaunchKey = "pikicam.first-launch"

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

    static func firstLaunchDate() -> Date {
        if let stored = UserDefaults.standard.object(forKey: firstLaunchKey) as? Date {
            return stored
        }
        let now = Date()
        UserDefaults.standard.set(now, forKey: firstLaunchKey)
        return now
    }

    nonisolated static func ensureAlbum() async throws -> PHAssetCollection? {
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

    nonisolated static func add(_ assetID: String, to album: PHAssetCollection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                guard let asset = PHAsset.fetchAssets(
                    withLocalIdentifiers: [assetID], options: nil
                ).firstObject else { return }
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

    /// Bounded legacy scan: assets created after pikicam's first launch on
    /// this device, newest first, hard fetch limit, called from a
    /// non-main context only.
    nonisolated static func legacyPIKIAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "creationDate >= %@", firstLaunchDate() as CVarArg)
        options.fetchLimit = 200
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

    static func dryRun() -> MigrationReport {
        let inAlbum = album().map { collection in
            PHAsset.fetchAssets(in: collection, options: nil).count
        } ?? 0
        return MigrationReport(
            beforeInAlbum: inAlbum,
            legacyFound: -1,
            moved: 0,
            foreignTouched: 0,
            alreadyDone: UserDefaults.standard.bool(forKey: migrationKey)
        )
    }

    nonisolated static func migrate() async throws -> MigrationReport {
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return MigrationReport(
                beforeInAlbum: 0, legacyFound: 0, moved: 0,
                foreignTouched: 0, alreadyDone: true
            )
        }
        let legacy = legacyPIKIAssets()
        guard let album = try await ensureAlbum() else {
            throw CocoaError(.userActivityConnectionUnavailable)
        }
        let before = PHAsset.fetchAssets(in: album, options: nil).count
        for asset in legacy {
            try? await add(asset.localIdentifier, to: album)
        }
        let after = PHAsset.fetchAssets(in: album, options: nil).count
        UserDefaults.standard.set(true, forKey: migrationKey)
        return MigrationReport(
            beforeInAlbum: before,
            legacyFound: legacy.count,
            moved: after - before,
            foreignTouched: 0,
            alreadyDone: false
        )
    }

    /// The archive listing: album-scoped, fast, main-thread safe.
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

    final class AlbumBox: @unchecked Sendable {
        var placeholder = ""
    }
}
