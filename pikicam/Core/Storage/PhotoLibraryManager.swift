import Foundation
import Photos
import UniformTypeIdentifiers

// MARK: - StorageService

/// Manages saving captured photo pairs (DNG negative + JPEG/HEIC print)
/// to the user's Photos library using `PHAssetCreationRequest`.
///
/// ## Saving Strategy
/// Each capture is saved as a single `PHAsset` with two resources:
/// - `.photo` — the developed JPEG/HEIC print (primary asset resource)
/// - `.alternatePhoto` — the untouched DNG negative (raw companion resource)
///
/// This keeps the negative and print together in the user's library and
/// supports "Revert to Original" in Photos.app for the DNG.
actor StorageService {

    // MARK: - Save Pair

    /// Saves a processed image and its raw DNG companion to the Photos library.
    ///
    /// - Parameters:
    ///   - processedData: JPEG or HEIC image data for the "print".
    ///   - rawData: DNG file data for the "negative".
    ///   - identifier: Optional unique identifier for filename (UUID used if nil).
    ///   - codec: Output codec for the processed print. Defaults to `.jpeg` so
    ///     existing callers compile; pass the selected codec to honor user choice.
    /// - Returns: The local identifier of the created `PHAsset`.
    /// - Throws: `StorageServiceError` if the save fails or permissions are insufficient.
    @discardableResult
    func savePair(
        processedData: Data,
        rawData: Data,
        identifier: String = UUID().uuidString,
        codec: UTType = .jpeg
    ) async throws -> String {
        // Ensure we have add-only permission.
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw StorageServiceError.insufficientPermissions(status: status)
        }

        // Use a checked continuation to bridge the PHPhotoLibrary callback.
        return try await withCheckedThrowingContinuation { continuation in
            let placeholderStore = AssetPlaceholderStore()

            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()

                // Per Apple's RAW+processed convention, the developed print is the
                // PRIMARY `.photo` resource and the DNG is stored as its
                // `.alternatePhoto` raw companion. (Assigning the DNG as the primary
                // resource is rejected by Photos with PHPhotosErrorChangeNotSupported.)
                let processedOptions = PHAssetResourceCreationOptions()
                processedOptions.originalFilename = "\(identifier).\(Self.fileExtension(for: codec))"
                processedOptions.uniformTypeIdentifier = codec.identifier
                creationRequest.addResource(
                    with: .photo,
                    data: processedData,
                    options: processedOptions
                )

                let rawOptions = PHAssetResourceCreationOptions()
                rawOptions.originalFilename = "\(identifier).dng"
                rawOptions.uniformTypeIdentifier = UTType(filenameExtension: "dng")?.identifier ?? "com.adobe.raw-image"
                creationRequest.addResource(
                    with: .alternatePhoto,
                    data: rawData,
                    options: rawOptions
                )

                placeholderStore.localIdentifier = creationRequest.placeholderForCreatedAsset?.localIdentifier

            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: StorageServiceError.saveFailed(underlying: error))
                } else if let localID = placeholderStore.localIdentifier {
                    continuation.resume(returning: localID)
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
