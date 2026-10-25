import Foundation
import Photos
import UIKit

final class SeedObserver: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    nonisolated(unsafe) static var observedAdds = 0
    nonisolated(unsafe) static var observedForeignMutations = 0
    nonisolated(unsafe) static var knownAlbumCount = -1
    nonisolated(unsafe) static var knownForeignIDs = Set<String>()

    static func reset() {
        observedAdds = 0
        observedForeignMutations = 0
        knownAlbumCount = -1
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        trackAlbum(changeInstance)
        trackForeign(changeInstance)
    }

    private func trackAlbum(_ changeInstance: PHChange) {
        let collections = changeInstance.changeDetails(
            for: PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        )
        guard let collections else { return }
        for collection in collections.insertedObjects where collection.localizedTitle == Archive.albumTitle {
            Self.observedAdds += 1
            Self.knownAlbumCount = 0
        }
        for collection in collections.changedObjects where collection.localizedTitle == Archive.albumTitle {
            guard
                let changes = changeInstance.changeDetails(for: collection),
                let after = changes.objectAfterChanges
            else { continue }
            let count = PHAsset.fetchAssets(in: after, options: nil).count
            if Self.knownAlbumCount >= 0, count > Self.knownAlbumCount {
                Self.observedAdds += 1
            }
            Self.knownAlbumCount = count
        }
    }

    private func trackForeign(_ changeInstance: PHChange) {
        let fetch = PHAsset.fetchAssets(with: nil)
        let details = changeInstance.changeDetails(for: fetch)
        guard let details else { return }
        for asset in details.changedObjects {
            guard Self.knownForeignIDs.contains(asset.localIdentifier),
                let objectDetails = changeInstance.changeDetails(for: asset),
                objectDetails.assetContentChanged
            else { continue }
            Self.observedForeignMutations += 1
        }
    }
}

enum SeedLibrary {
    struct Report: Codable {
        let foreignCreated: Int
        let legacyPICreated: Int
        let albumExistedBefore: Bool
        let saveAlbumAdds: Int
        let foreignMutated: Int
    }

    @MainActor
    static func run() async {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("seed-report.json")
        try? Data().write(to: url)

        SeedObserver.reset()
        PHPhotoLibrary.shared().register(SeedObserver())

        let foreign = await seedForeign()
        let legacy = await seedLegacy()
        let albumExistedBefore = Archive.album() != nil

        let engine = CameraEngine()
        engine.isMonoOn = false
        await engine.start()
        for _ in 0..<40 where !engine.isRunning {
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        if let capture = await engine.capturePhoto() {
            await engine.saveToPhotos(capture)
        }
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        let report = Report(
            foreignCreated: foreign,
            legacyPICreated: legacy,
            albumExistedBefore: albumExistedBefore,
            saveAlbumAdds: SeedObserver.observedAdds,
            foreignMutated: SeedObserver.observedForeignMutations
        )
        if let data = try? JSONEncoder().encode(report) {
            try? data.write(to: url, options: [.atomic])
        }
        WalkMark.mark(
            "seed-done foreign=\(foreign) legacy=\(legacy) "
                + "adds=\(SeedObserver.observedAdds) foreignMut=\(SeedObserver.observedForeignMutations)"
        )
    }

    private static func seedForeign() async -> Int {
        let colors = [(0.9, 0.3), (0.9, 0.3), (0.9, 0.3), (0.1, 0.7)]
        let names = [
            "FOREIGN_holiday_0.heic", "FOREIGN_holiday_1.heic",
            "FOREIGN_holiday_2.heic", "FOREIGN_screenshot_0.png",
        ]
        var count = 0
        for (index, name) in names.enumerated() {
            let color = colors[index]
            if await seedImage(color.0, color.1, name: name) != nil {
                count += 1
            }
        }
        for index in 0..<2 where await seedVideo(name: "FOREIGN_trip_\(index).mov") != nil {
            count += 1
        }
        return count
    }

    private static func seedLegacy() async -> Int {
        var count = 0
        for index in 0..<2 where await seedImage(0.2, 0.2, name: "PIKI_20250101_00000\(index).heic") != nil {
            count += 1
        }
        return count
    }

    private static func seedImage(
        _ red: Double, _ green: Double, name: String
    ) async -> String? {
        guard let png = renderPNG(red: red, green: green) else { return nil }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = name
                request.addResource(with: .photo, data: png, options: options)
                if let placeholder = request.placeholderForCreatedAsset {
                    SeedObserver.knownForeignIDs.insert(placeholder.localIdentifier)
                }
            } completionHandler: { success, _ in
                continuation.resume(returning: success ? name : nil)
            }
        }
    }

    private static func renderPNG(red: Double, green: Double) -> Data? {
        let width = 64, height = 64
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        ctx?.setFillColor(CGColor(red: red, green: green, blue: 0.2, alpha: 1))
        ctx?.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cg = ctx?.makeImage() else { return nil }
        return UIImage(cgImage: cg).pngData()
    }

    private static func seedVideo(name: String) async -> String? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        guard await renderVideoSeed(to: url) else { return nil }
        let box = IDBox()
        let saved = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = name
                request.addResource(with: .video, fileURL: url, options: options)
                box.id = request.placeholderForCreatedAsset?.localIdentifier ?? ""
            } completionHandler: { success, _ in
                continuation.resume(returning: success)
            }
        }
        try? FileManager.default.removeItem(at: url)
        if saved, !box.id.isEmpty {
            SeedObserver.knownForeignIDs.insert(box.id)
            return name
        }
        return nil
    }

    private static func renderVideoSeed(to url: URL) async -> Bool {
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return false }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: 320,
            AVVideoHeightKey: 240,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 320,
            kCVPixelBufferHeightKey as String: 240,
        ])
        for frame in 0..<30 {
            while !input.isReadyForMoreMediaData { usleep(5000) }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adapter.pixelBufferPool!, &pb)
            if let pb {
                let t = Double(frame) / 30.0
                CIContext().render(
                    CIImage(color: CIColor(red: t, green: 0.5, blue: 0.2))
                        .cropped(to: CGRect(x: 0, y: 0, width: 320, height: 240)),
                    to: pb
                )
                adapter.append(pb, withPresentationTime: CMTime(seconds: t, preferredTimescale: 30))
            }
        }
        input.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting { continuation.resume() }
        }
        return true
    }

    private final class IDBox: @unchecked Sendable {
        var id = ""
    }
}
