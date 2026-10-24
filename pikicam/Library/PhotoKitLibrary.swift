import Foundation
import Photos
import UniformTypeIdentifiers

actor PhotoKitLibrary: Library {
    private var continuation: AsyncStream<[LibraryItem]>.Continuation?
    private var debounceTask: Task<Void, Never>?

    nonisolated var changes: AsyncStream<[LibraryItem]> {
        AsyncStream { continuation in
            Task { await self.register(continuation) }
        }
    }

    private nonisolated(unsafe) var observer: LibraryChangeObserver?

    private func register(_ continuation: AsyncStream<[LibraryItem]>.Continuation) {
        self.continuation = continuation
        let observer = LibraryChangeObserver { [weak self] in
            Task { await self?.debouncePublish() }
        }
        self.observer = observer
        PHPhotoLibrary.shared().register(observer)
        let items = Self.fetchItems()
        continuation.yield(items)
    }

    private func publishCurrent() {
        let items = Self.fetchItems()
        continuation?.yield(items)
    }

    private func debouncePublish() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await self?.publishCurrent()
        }
    }

    nonisolated private static func fetchItems() -> [LibraryItem] {
        let albumID = UserDefaults.standard.string(forKey: "pikicam.album.localIdentifier")
        let fetch: PHFetchResult<PHAsset>
        if let albumID,
            let album = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [albumID], options: nil
            ).firstObject
        {
            fetch = PHAsset.fetchAssets(in: album, options: fetchOptions())
        } else {
            fetch = PHAsset.fetchAssets(with: fetchOptions())
        }
        var items: [LibraryItem] = []
        fetch.enumerateObjects { asset, _, _ in
            items.append(AssetBoundary.libraryItem(from: asset))
        }
        return items
    }

    nonisolated private static func fetchOptions() -> PHFetchOptions {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return options
    }

    func save(
        _ raw: RawCapture, rendition: Rendition?, payload: AdjustmentPayload
    ) throws(LibraryError) -> LibraryItem {
        try saveSync {
            let album = try Album.fetchOrCreateSync()
            let request = PHAssetCreationRequest.forAsset()
            request.creationDate = raw.provenance.capturedAt
            let dngOptions = PHAssetResourceCreationOptions()
            let base = "PIKI_\(raw.id.id.uuidString.prefix(4))"
            dngOptions.originalFilename = Self.filename(base: base, ext: "dng", at: raw.provenance.capturedAt)
            dngOptions.uniformTypeIdentifier = UTType(filenameExtension: "dng")?.identifier
            request.addResource(with: .photo, data: raw.dng, options: dngOptions)
            if let rendition {
                let heicOptions = PHAssetResourceCreationOptions()
                heicOptions.originalFilename = Self.filename(base: base, ext: "heic", at: raw.provenance.capturedAt)
                heicOptions.uniformTypeIdentifier = "public.heic"
                request.addResource(with: .fullSizePhoto, data: rendition.heic, options: heicOptions)
            }
            PHAssetCollectionChangeRequest(for: album)?.addAssets([request.placeholderForCreatedAsset!] as NSArray)
        }
        return LibraryItem(
            id: AssetID(localIdentifier: "pending-\(raw.id)"),
            captureID: raw.id,
            creationDate: raw.provenance.capturedAt,
            mediaKind: .photo,
            developState: rendition == nil ? .pending : .developed
        )
    }

    private func saveSync(_ change: @escaping () throws -> Void) throws(LibraryError) {
        WalkMark.mark("performChanges-begin")
        let semaphore = DispatchSemaphore(value: 0)
        var thrown: Error?
        PHPhotoLibrary.shared().performChanges {
            do {
                try change()
            } catch {
                thrown = error
            }
            semaphore.signal()
        }
        semaphore.wait()
        WalkMark.mark("performChanges-end")
        if let thrown {
            throw Self.map(thrown)
        }
    }

    nonisolated static func map(_ error: Error) -> LibraryError {
        .saveFailed(code: (error as NSError).code)
    }

    nonisolated private static func filename(base: String, ext: String, at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "\(base)_\(formatter.string(from: date)).\(ext)"
    }

    func saveVideo(_ clip: VideoClip, payload: AdjustmentPayload) throws(LibraryError) -> LibraryItem {
        let item = LibraryItem(
            id: AssetID(localIdentifier: "pending-\(clip.id)"),
            captureID: nil,
            creationDate: Date(),
            mediaKind: .video(ClipInfo(clipID: clip.id, duration: clip.duration, mode: clip.mode)),
            developState: .developed
        )
        return item
    }

    func saveScan(
        _ result: ScanResult, rendition: Rendition?, payload: AdjustmentPayload
    ) throws(LibraryError) -> LibraryItem {
        LibraryItem(
            id: AssetID(localIdentifier: "pending-\(result.id)"),
            captureID: result.id,
            creationDate: Date(),
            mediaKind: .photo,
            developState: rendition == nil ? .pending : .developed
        )
    }

    func items() -> [LibraryItem] {
        Self.fetchItems()
    }

    func dng(for id: AssetID) async throws(LibraryError) -> Data {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id.localIdentifier], options: nil)
        guard let asset = assets.firstObject else {
            throw .assetMissing
        }
        do {
            return try await AssetBoundary.dngData(for: asset)
        } catch {
            throw error
        }
    }

    func commitEdit(_ id: AssetID, payload: AdjustmentPayload, rendition: Rendition?) throws(LibraryError) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id.localIdentifier], options: nil)
        guard let asset = assets.firstObject else {
            throw .assetMissing
        }
        let semaphore = DispatchSemaphore(value: 0)
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest(for: asset)
            request.contentEditingOutput = Self.editingOutput(asset: asset, rendition: rendition, payload: payload)
            semaphore.signal()
        }
        semaphore.wait()
    }

    nonisolated private static func editingOutput(
        asset: PHAsset, rendition: Rendition?, payload: AdjustmentPayload
    ) -> PHContentEditingOutput? {
        guard let rendition else { return nil }
        let output = PHContentEditingOutput(contentEditingInput: PHContentEditingInput())
        do {
            let url = try output.renderedContentURL(for: .heic)
            try rendition.heic.write(to: url, options: [.atomic])
        } catch {
            return nil
        }
        output.adjustmentData = AdjustmentCodec.encode(payload)
        return output
    }

    func revert(_ id: AssetID) throws(LibraryError) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id.localIdentifier], options: nil)
        guard let asset = assets.firstObject else {
            throw .assetMissing
        }
        let box = InputBox()
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = false
        options.canHandleAdjustmentData = { _ in false }
        let semaphore = DispatchSemaphore(value: 0)
        asset.requestContentEditingInput(with: options) { input, _ in
            box.input = input
            semaphore.signal()
        }
        semaphore.wait()
        guard let contentInput = box.input else {
            throw .editFailed
        }
        let output = PHContentEditingOutput(contentEditingInput: contentInput)
        output.adjustmentData = nil
        let commitSemaphore = DispatchSemaphore(value: 0)
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest(for: asset).contentEditingOutput = output
            commitSemaphore.signal()
        }
        commitSemaphore.wait()
    }

    private final class InputBox: @unchecked Sendable {
        var input: PHContentEditingInput?
    }

    func delete(_ id: AssetID) throws(LibraryError) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id.localIdentifier], options: nil)
        guard let asset = assets.firstObject else {
            throw .assetMissing
        }
        let semaphore = DispatchSemaphore(value: 0)
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            semaphore.signal()
        }
        semaphore.wait()
    }
}

final class LibraryChangeObserver: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    private let onChange: @Sendable () -> Void

    init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
        super.init()
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        onChange()
    }
}
