import Photos
import UniformTypeIdentifiers

// MARK: - StorageService

/// Manages saving captured photo pairs (DNG negative + JPEG/HEIC print)
/// to the user's Photos library using `PHAssetCreationRequest`.
///
/// ## Saving Strategy (verified on-device, iOS 26.6)
///
/// PhotoKit on iOS 26.6 rejects the `.alternatePhoto` pairing layout
/// (`PHPhotosErrorChangeNotSupported` / 3300) regardless of authorization
/// level, resource UTIs, or pairing order. The working approach saves
/// *two independent assets* (each a `.photo` resource):
///
/// - Asset 1 — the developed JPEG/HEIC print.
/// - Asset 2 — the untouched DNG negative (`.photo` resource, `.dng` UT).
///
/// Both assets are created in a single `performChanges` batch.
actor StorageService {

    // MARK: - Save Pair

    /// Saves the developed print and its raw DNG companion as two separate
    /// Photos assets (verified on-device: `.alternatePhoto` pairing fails
    /// with `PHPhotosErrorDomain` 3300 on iOS 26.6).
    ///
    /// - Returns: `(printLocalID, rawLocalID)` — both non-empty on success.
    /// - Throws: `StorageServiceError` if either save fails.
    @discardableResult
    func savePair(
        processedData: Data,
        rawData: Data,
        identifier: String = UUID().uuidString,
        codec: UTType = .jpeg
    ) async throws -> (String, String) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized else {
            throw StorageServiceError.insufficientPermissions(status: status)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let printStore = AssetPlaceholderStore()
            let rawStore = AssetPlaceholderStore()

            PHPhotoLibrary.shared().performChanges {
                // Print asset (independent `.photo` resource).
                let printReq = PHAssetCreationRequest.forAsset()
                let printOptions = PHAssetResourceCreationOptions()
                printOptions.originalFilename = "\(identifier).\(Self.fileExtension(for: codec))"
                printOptions.uniformTypeIdentifier = codec.identifier
                printReq.addResource(with: .photo, data: processedData, options: printOptions)
                printStore.localIdentifier = printReq.placeholderForCreatedAsset?.localIdentifier

                // Negative asset (independent `.photo` resource with DNG data).
                let rawReq = PHAssetCreationRequest.forAsset()
                let rawOptions = PHAssetResourceCreationOptions()
                rawOptions.originalFilename = "\(identifier).dng"
                rawOptions.uniformTypeIdentifier = UTType(filenameExtension: "dng")?.identifier
                    ?? "com.adobe.raw-image"
                rawReq.addResource(with: .photo, data: rawData, options: rawOptions)
                rawStore.localIdentifier = rawReq.placeholderForCreatedAsset?.localIdentifier

            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: StorageServiceError.saveFailed(underlying: error))
                } else if let p = printStore.localIdentifier, let r = rawStore.localIdentifier {
                    continuation.resume(returning: (p, r))
                } else {
                    continuation.resume(throwing: StorageServiceError.unknownSaveFailure)
                }
            }
        }
    }

    // MARK: - Helpers

    /// File extension for the given output codec, used for the saved asset's
    /// original filename. Defaults to `jpg` for unknown codecs.
    private static func fileExtension(for codec: UTType) -> String {
        switch codec {
        case .jpeg: return "jpg"
        case .heic: return "heic"
        case .tiff: return "tiff"
        default: return "jpg"
        }
    }
}

private nonisolated final class AssetPlaceholderStore: @unchecked Sendable {
    var localIdentifier: String?
}

// MARK: - Errors

enum StorageServiceError: LocalizedError {
    case insufficientPermissions(status: PHAuthorizationStatus)
    case saveFailed(underlying: Error)
    case unknownSaveFailure

    var errorDescription: String? {
        switch self {
        case .insufficientPermissions(let status):
            return "Photo library permission denied. Current status: \(status.rawValue)."
        case .saveFailed(let error):
            return "Failed to save photo: \(error.localizedDescription)"
        case .unknownSaveFailure:
            return "An unknown error occurred while saving the photo."
        }
    }
}
