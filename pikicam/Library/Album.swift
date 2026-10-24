import Foundation
import Photos

enum Album {
    private static let identifierKey = "pikicam.album.localIdentifier"
    private static let title = "pikicam"

    static func fetchOrCreateSync() throws(LibraryError) -> PHAssetCollection {
        WalkMark.mark("album-fetch-begin")
        let semaphore = DispatchSemaphore(value: 0)
        let box = AlbumBox()
        Task {
            box.result = await attemptFetchOrCreate()
            semaphore.signal()
        }
        semaphore.wait()
        switch box.result {
        case .success(let collection):
            return collection
        case .failure(let error):
            throw error
        case nil:
            throw LibraryError.albumUnavailable
        }
    }

    private final class AlbumBox: @unchecked Sendable {
        var result: Result<PHAssetCollection, LibraryError>?
    }

    private static func attemptFetchOrCreate() async -> Result<PHAssetCollection, LibraryError> {
        do {
            return .success(try await fetchOrCreate())
        } catch {
            return .failure(.albumUnavailable)
        }
    }

    static func fetchOrCreate() async throws(LibraryError) -> PHAssetCollection {
        let defaults = UserDefaults.standard
        if let identifier = defaults.string(forKey: identifierKey) {
            let fetched = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [identifier], options: nil
            )
            if let collection = fetched.firstObject {
                return collection
            }
        }
        let byTitle = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: nil
        )
        let all = byTitle.objects(at: IndexSet(integersIn: 0..<byTitle.count))
        let matching = all.filter { $0.localizedTitle == title }
        if let existing = matching.first {
            defaults.set(existing.localIdentifier, forKey: identifierKey)
            return existing
        }
        do {
            var placeholder: PHObjectPlaceholder?
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
                placeholder = request.placeholderForCreatedAssetCollection
            }
            guard let placeholderID = placeholder?.localIdentifier else {
                throw LibraryError.albumUnavailable
            }
            let created = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [placeholderID], options: nil
            )
            guard let collection = created.firstObject else {
                throw LibraryError.albumUnavailable
            }
            defaults.set(collection.localIdentifier, forKey: identifierKey)
            return collection
        } catch let error as LibraryError {
            throw error
        } catch {
            throw .albumUnavailable
        }
    }
}
