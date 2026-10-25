import Foundation
import Photos

enum Archive {
    static let albumTitle = "pikicam"
    private static let migrationKey = "pikicam.migration.done"
    private static let firstLaunchKey = "pikicam.first-launch"
    private static let consolidationKey = "pikicam.album-consolidation.done"

    static func album() -> PHAssetCollection? {
        canonicalAlbum()
    }

    static func canonicalAlbum() -> PHAssetCollection? {
        allAlbums().first
    }

    static func allAlbums() -> [PHAssetCollection] {
        let fetch = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var found: [PHAssetCollection] = []
        fetch.enumerateObjects { collection, _, _ in
            if collection.localizedTitle == albumTitle {
                found.append(collection)
            }
        }
        return found
    }

    static func memberCount(_ album: PHAssetCollection) -> Int {
        PHAsset.fetchAssets(in: album, options: nil).count
    }

    static func memberIDs(_ album: PHAssetCollection, limit: Int) -> [String] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        let fetch = PHAsset.fetchAssets(in: album, options: options)
        var ids: [String] = []
        fetch.enumerateObjects { asset, _, _ in ids.append(asset.localIdentifier) }
        return ids
    }

    static func holds(_ album: PHAssetCollection, _ assetID: String) -> Bool {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "localIdentifier = %@", assetID)
        return PHAsset.fetchAssets(in: album, options: options).count > 0
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
        if let existing = album() {
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

    struct ConsolidationReport: Codable {
        let duplicatesBefore: Int
        let moved: Int
        let deleted: Int
        let canonicalID: String
        let complete: Bool
    }

    static func markConsolidationUndone() {
        UserDefaults.standard.removeObject(forKey: consolidationKey)
    }

    static func markMigrationUndone() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
    }

    nonisolated static func consolidateIfNeeded() async -> ConsolidationReport? {
        guard !UserDefaults.standard.bool(forKey: consolidationKey) else { return nil }
        guard let canonical = canonicalAlbum() else { return nil }
        var duplicates = allAlbums().filter { $0.localIdentifier != canonical.localIdentifier }
        var moved = 0
        for album in duplicates {
            let members = PHAsset.fetchAssets(in: album, options: nil)
            guard members.count > 0 else { continue }
            let assets = members.objects(at: IndexSet(integersIn: 0..<members.count))
            do {
                try await move(assets, to: canonical)
                moved += assets.count
            } catch {
                WalkMark.mark("consolidation-move-failed")
            }
        }
        duplicates = allAlbums().filter { $0.localIdentifier != canonical.localIdentifier }
        var deleted = 0
        if !duplicates.isEmpty {
            do {
                try await deleteCollections(duplicates)
                deleted = duplicates.count
            } catch {
                WalkMark.mark("consolidation-delete-failed")
            }
        }
        let residue = allAlbums().contains {
            $0.localIdentifier != canonical.localIdentifier
        }
        let complete = !residue
        if complete {
            UserDefaults.standard.set(true, forKey: consolidationKey)
        }
        return ConsolidationReport(
            duplicatesBefore: duplicates.count + deleted,
            moved: moved,
            deleted: deleted,
            canonicalID: canonical.localIdentifier,
            complete: complete
        )
    }

    private nonisolated static func move(_ assets: [PHAsset], to album: PHAssetCollection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetCollectionChangeRequest(for: album)?.addAssets(assets as NSArray)
            } completionHandler: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private nonisolated static func deleteCollections(_ collections: [PHAssetCollection]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetCollectionChangeRequest.deleteAssetCollections(collections as NSArray)
            } completionHandler: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    static func fetchArchiveAssets() -> [PHAsset] {        guard let collection = album() else { return [] }
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
