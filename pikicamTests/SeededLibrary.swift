import AVFoundation
import CoreVideo
import Photos
import UIKit
import XCTest

@MainActor
enum SeededLibrary {
    struct Seeded {
        let localID: String
        let kind: Kind
        let filename: String

        enum Kind {
            case foreignHEIC
            case foreignVideo
            case legacyPIKIDNG
            case freshPIKI
        }
    }

    static var seeded: [Seeded] = []

    @discardableResult
    static func build(test: XCTestCase) async throws -> [Seeded] {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw CocoaError(.coderInvalidValue, userInfo: [
                NSLocalizedDescriptionKey: "photos access is \(status.rawValue), cannot seed"
            ])
        }
        await teardown()
        var made: [Seeded] = []
        let specs: [(String, Seeded.Kind)] = [
            ("foreign-1", .foreignHEIC), ("foreign-2", .foreignVideo),
            ("legacy-1", .legacyPIKIDNG), ("legacy-2", .legacyPIKIDNG),
            ("fresh-1", .freshPIKI),
        ]
        for spec in specs {
            let id = try await create(filename: spec.0, kind: spec.1)
            made.append(Seeded(localID: id, kind: spec.1, filename: spec.0))
        }
        seeded = made
        return made
    }

    private nonisolated static func create(filename: String, kind: Seeded.Kind) async throws -> String {
        if kind == .foreignVideo {
            return try await createVideo(filename: filename)
        }
        let box = IDBox()
        let prefix = kind == .foreignHEIC ? "IMG_" : "PIKI_"
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.creationDate = Date()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = "\(prefix)\(filename).jpg"
            request.addResource(with: .photo, data: Self.renderedJPEG(), options: options)
            box.created = request.placeholderForCreatedAsset?.localIdentifier ?? ""
        }
        return box.created
    }

    private nonisolated static func createVideo(filename: String) async throws -> String {
        let box = IDBox()
        let url = try await renderedClip()
        defer { try? FileManager.default.removeItem(at: url) }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.creationDate = Date()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = "VID_\(filename).mov"
            request.addResource(with: .video, fileURL: url, options: options)
            box.created = request.placeholderForCreatedAsset?.localIdentifier ?? ""
        }
        return box.created
    }

    nonisolated static func renderedJPEG() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800))
        let image = renderer.image { ctx in
            UIColor(hue: .random(in: 0...1), saturation: 0.6, brightness: 0.9, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 60, y: 60, width: 480, height: 680))
        }
        return image.jpegData(compressionQuality: 0.85) ?? Data()
    }

    nonisolated private static func renderedClip() async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("seed-clip-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 640,
            AVVideoHeightKey: 480,
        ])
        let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 640,
            kCVPixelBufferHeightKey as String: 480,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<30 {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            let buffer = try Self.pooledBuffer(adapter, frame: frame)
            let time = CMTime(value: CMTimeValue(frame), timescale: 30)
            adapter.append(buffer, withPresentationTime: time)
        }
        input.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting(completionHandler: continuation.resume)
        }
        guard writer.status == .completed else {
            throw CocoaError(.coderInvalidValue, userInfo: [
                NSLocalizedDescriptionKey: "seed clip writer status \(writer.status.rawValue)"
            ])
        }
        return url
    }

    nonisolated private static func pooledBuffer(
        _ adapter: AVAssetWriterInputPixelBufferAdaptor, frame: Int
    ) throws -> CVPixelBuffer {
        var pixel: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adapter.pixelBufferPool!, &pixel)
        let buffer = try XCTUnwrap(pixel)
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, Int32(40 + frame * 5), CVPixelBufferGetDataSize(buffer))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    nonisolated private static func deleteSeeded(_ assets: [PHAsset]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
    }

    static func teardown() async {
        let ids = seeded.map(\.localID)
        guard !ids.isEmpty else { return }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assets: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in assets.append(asset) }
        guard !assets.isEmpty else { return }
        try? await deleteSeeded(assets)
        seeded = []
    }
}

final class IDBox: @unchecked Sendable {
    var created = ""
}
