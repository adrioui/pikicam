
import Foundation
import SwiftUI
import Photos

@Observable
final class PikicamLibraryModel {
    let manager = PhotoLibraryManager()
    private(set) var captures: [PikicamCapture] = []
    private(set) var selectedCapture: PikicamCapture?
    private(set) var isLoading = false
    var error: PhotoLibraryError?
    private var invalidationTask: Task<Void, Never>?

    init() {
        Task { await refresh() }
        invalidationTask = Task { await watchInvalidation() }
    }

    deinit {
        invalidationTask?.cancel()
    }

    func refresh() async {
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
        for await _ in manager.invalidationUpdates() {
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
            await refresh()
            return true
        } catch {
            self.error = .deleteFailed(PhotoFailure(error as NSError))
            return false
        }
    }

    func loadThumbnail(for assetID: PhotoAssetID) async throws -> UIImage {
        try await manager.requestThumbnail(for: assetID, targetPixelSize: CGSize(width: 300, height: 300))
    }


    func save(_ dngData: Data) async throws -> PikicamCapture {
        let capturedDNG = CapturedDNG(data: dngData, capturedAt: Date())
        let capture = try await manager.save(capturedDNG)
        await refresh()
        return capture
    }
    func loadOriginalDNG(for assetID: PhotoAssetID) async throws -> Data {
        try await manager.loadOriginalDNG(for: assetID)
    }
}
