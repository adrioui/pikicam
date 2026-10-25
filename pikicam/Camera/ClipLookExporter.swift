import AVFoundation
import CoreImage
import Foundation

enum ClipLookExporter {
    static func monochromeVersion(of source: URL) async -> URL? {
        let asset = AVURLAsset(url: source)
        let composition: AVVideoComposition?
        do {
            composition = try await AVVideoComposition(
                applyingFiltersTo: asset,
                applier: { parameters in
                    AVCIImageFilteringResult(resultImage: Look.apply(to: parameters.sourceImage, mono: true))
                }
            )
        } catch {
            return nil
        }
        guard let composition else { return nil }
        guard let export = AVAssetExportSession(
            asset: asset, presetName: AVAssetExportPresetHighestQuality
        ) else { return nil }
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("piki-mono-\(UUID().uuidString).mov")
        try? FileManager.default.removeItem(at: output)
        export.outputURL = output
        export.outputFileType = .mov
        export.videoComposition = composition
        do {
            try await export.export(to: output, as: AVFileType.mov)
            return output
        } catch {
            return nil
        }
    }
}
