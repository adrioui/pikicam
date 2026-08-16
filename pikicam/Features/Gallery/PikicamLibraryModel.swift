import Foundation
import SwiftUI
import Photos

@MainActor
@Observable
final class PikicamLibraryModel: @unchecked Sendable {
    nonisolated let manager = PhotoLibraryManager()
    private(set) var captures: [PikicamCapture] = []
    private(set) var selectedCapture: PikicamCapture?
    private(set) var isLoading = false
    var error: PhotoLibraryError?
    private var invalidationTask: Task<Void, Never>?

    init() {
        Task { [weak self] in
            await self?.refresh()
        }
        invalidationTask = Task { [weak self] in
            await self?.watchInvalidation()
        }
    }

    // The invalidation task captures the model weakly and ends when the model does.

    func refresh() async {
        // Keep the last-known captures on error: a transient PhotoKit failure
        // (iCloud hiccup, limited-auth visibility change) must not wipe the
        // gallery. The error is published orthogonally so the UI can show a
        // non-blocking banner over the stale grid.
        isLoading = true
        do {
            captures = try await manager.captures()
            self.error = nil
        } catch let err as PhotoLibraryError {
            self.error = err
        } catch {
            self.error = PhotoLibraryError.unknownFailure
        }
        isLoading = false
    }

    private func watchInvalidation() async {
        let updates = await manager.invalidationUpdates()
        for await _ in updates {
            await refresh()
        }
    }

    func select(_ capture: PikicamCapture) {
        selectedCapture = capture
    }

    func deleteSelected() async -> Bool {
        guard let capture = selectedCapture else { return false }
        do {
            try await manager.delete(capture)
            selectedCapture = nil
            // Refresh immediately — same reasoning as `save`: the PhotoKit
            // change notification is asynchronous and the UI asserts the
            // removal right after the delete completes.
            await refresh()
            return true
        } catch let err as PhotoLibraryError {
            self.error = err
            return false
        } catch {
            self.error = .deleteFailed(PhotoFailure(error as NSError))
            return false
        }
    }

    func loadThumbnail(for assetID: PhotoAssetID) async throws -> UIImage {
        try await manager.requestThumbnail(for: assetID, targetPixelSize: CGSize(width: 300, height: 300))
    }

    func save(_ dng: CapturedDNG) async throws -> PikicamCapture {
        let capture = try await manager.save(dng)
        // Refresh immediately: the PhotoKit change notification for our own
        // save is asynchronous and can race the caller opening the gallery,
        // leaving the new capture invisible. An explicit refresh makes the
        // save visible right away; a later invalidation refresh is a no-op.
        await refresh()
        return capture
    }

    func loadOriginalDNG(for assetID: PhotoAssetID) async throws -> Data {
        try await manager.loadOriginalDNG(for: assetID)
    }
}
