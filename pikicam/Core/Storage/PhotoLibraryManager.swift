import Photos
import UniformTypeIdentifiers

// MARK: - StorageService

/// Saves pikicam captures to the user's Photos library.
///
/// iOS 26.6 rejects the `.alternatePhoto` pairing layout
/// (`PHPhotosErrorChangeNotSupported` / 3300), so the DNG and the print
/// are saved as two independent `.photo` resources in a single
/// `performChanges` batch.
actor StorageService {

    // MARK: - Save

    /// Saves the developed print and its raw DNG companion as two separate
    /// Photos assets.
    ///
    /// - Returns: `(printLocalID, rawLocalID)` — both non-empty on success.
    /// - Throws: `StorageServiceError` if the save fails.
    @discardableResult
    func savePair(
        processedData: Data,
        rawData: Data,
        identifier: String = UUID().uuidString,
        codec: UTType = .jpeg
    ) async throws -> (String, String) {
        try await checkAuthorization()
        let (printID, rawID) = try await performChanges(
            printData: processedData, rawData: rawData, identifier: identifier, codec: codec
        )
        guard let rawID else {
            throw StorageServiceError.unknownSaveFailure
        }
        return (printID, rawID)
    }

    /// Saves only the developed print (RAW output is disabled).
    ///
    /// - Returns: The print asset's local identifier.
    /// - Throws: `StorageServiceError` if the save fails.
    @discardableResult
    func savePrintOnly(
        processedData: Data,
        identifier: String = UUID().uuidString,
        codec: UTType = .jpeg
    ) async throws -> String {
        try await checkAuthorization()
        let (printID, _) = try await performChanges(printData: processedData, rawData: nil, identifier: identifier, codec: codec)
        return printID
    }

    /// Deletes the print and (if present) the DNG asset from the Photos
    /// library. Missing assets are skipped — no error.
    func deletePair(printID: String, rawID: String?) async throws {
        try await checkAuthorization()
        let ids = [printID, rawID].compactMap { $0 }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            } completionHandler: { _, error in
                if let error {
                    continuation.resume(throwing: StorageServiceError.deleteFailed(underlying: error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Private

    private func checkAuthorization() throws {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
            throw StorageServiceError.insufficientPermissions(status: PHPhotoLibrary.authorizationStatus(for: .readWrite))
        }
    }

    /// Performs a single `performChanges` batch creating one or two assets.
    /// When `rawData` is nil, only the print asset is created.
    private func performChanges(
        printData: Data,
        rawData: Data?,
        identifier: String,
        codec: UTType
    ) async throws -> (String, String?) {
        try await withCheckedThrowingContinuation { continuation in
            let printStore = AssetPlaceholderStore()
            let rawStore = AssetPlaceholderStore()

            PHPhotoLibrary.shared().performChanges {
                let printReq = PHAssetCreationRequest.forAsset()
                let printOptions = PHAssetResourceCreationOptions()
                printOptions.originalFilename = "\(identifier).\(Self.fileExtension(for: codec))"
                printOptions.uniformTypeIdentifier = codec.identifier
                printReq.addResource(with: .photo, data: printData, options: printOptions)
                printStore.localIdentifier = printReq.placeholderForCreatedAsset?.localIdentifier

                if let rawData {
                    let rawReq = PHAssetCreationRequest.forAsset()
                    let rawOptions = PHAssetResourceCreationOptions()
                    rawOptions.originalFilename = "\(identifier).dng"
                    rawOptions.uniformTypeIdentifier = UTType(filenameExtension: "dng")?.identifier
                        ?? "com.adobe.raw-image"
                    rawReq.addResource(with: .photo, data: rawData, options: rawOptions)
                    rawStore.localIdentifier = rawReq.placeholderForCreatedAsset?.localIdentifier
                }

            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: StorageServiceError.saveFailed(underlying: error))
                } else if let p = printStore.localIdentifier {
                    continuation.resume(returning: (p, rawStore.localIdentifier))
                } else {
                    continuation.resume(throwing: StorageServiceError.unknownSaveFailure)
                }
            }
        }
    }

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
    case deleteFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .insufficientPermissions(let status):
            return "Photo library permission denied. Current status: \(status.rawValue)."
        case .saveFailed(let error):
            return "Failed to save photo: \(error.localizedDescription)"
        case .unknownSaveFailure:
            return "An unknown error occurred while saving the photo."
        case .deleteFailed(let error):
            return "Failed to delete photo: \(error.localizedDescription)"
        }
    }
}
