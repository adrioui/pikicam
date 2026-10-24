import Foundation
import Photos
import UniformTypeIdentifiers

enum AssetBoundary {
    static func isPikicamDNG(resource: PHAssetResource) -> Bool {
        let rawUTIs = ["com.adobe.raw-image", "public.camera-raw-image"]
        let uti = resource.uniformTypeIdentifier
        if rawUTIs.contains(uti) {
            return true
        }
        return resource.originalFilename.hasSuffix(".dng")
    }

    static func libraryItem(from asset: PHAsset) -> LibraryItem {
        let resources = PHAssetResource.assetResources(for: asset)
        let hasDNG = resources.contains { isPikicamDNG(resource: $0) }
        let mediaKind: MediaKind = asset.mediaType == .video
            ? .video(ClipInfo(clipID: ClipID(), duration: asset.duration, mode: .res1080p30))
            : .photo
        let developState: DevelopState = hasDNG && asset.hasAdjustments ? .developed : .developed
        return LibraryItem(
            id: AssetID(localIdentifier: asset.localIdentifier),
            captureID: hasDNG ? captureID(from: asset) : nil,
            creationDate: asset.creationDate ?? Date(),
            mediaKind: mediaKind,
            developState: developState
        )
    }

    static func captureID(from asset: PHAsset) -> CaptureID? {
        guard let identifier = asset.value(forKey: "localIdentifier") as? String else { return nil }
        _ = identifier
        return nil
    }

    static func dngData(for asset: PHAsset) async throws(LibraryError) -> Data {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let dngResource = resources.first(where: { isPikicamDNG(resource: $0) }) else {
            throw .resourceMissing
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("piki-dng-\(UUID().uuidString).dng")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            try await PHAssetResourceManager.default().writeData(for: dngResource, toFile: url, options: nil)
            guard let data = try? Data(contentsOf: url) else {
                throw LibraryError.resourceMissing
            }
            return data
        } catch let error as LibraryError {
            throw error
        } catch {
            throw .resourceMissing
        }
    }

    static func uti(for extensionName: String) -> String {
        UTType(filenameExtension: extensionName)?.identifier ?? "public.data"
    }
}
