import CoreImage
import Foundation
import UniformTypeIdentifiers

enum BNWDeveloper {
    static func monochromeHEIC(from capture: CaptureResult) async -> Data? {
        let data = capture.data
        return await Task.detached(priority: .userInitiated) {
            develop(data: data)
        }.value
    }

    private static func develop(data: Data) -> Data? {
        let image: CIImage
        if captureIsRaw(data) {
            guard let filter = CIRAWFilter(imageData: data, identifierHint: UTType.rawImage.identifier),
                filter.outputImage != nil
            else {
                return nil
            }
            filter.boostAmount = 0
            filter.extendedDynamicRangeAmount = 1
            filter.isLensCorrectionEnabled = false
            guard let raw = filter.outputImage else { return nil }
            image = raw
        } else {
            guard let decoded = CIImage(data: data) else { return nil }
            image = decoded
        }
        let mono = image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,
        ])
        guard let space = CGColorSpace(name: CGColorSpace.displayP3) else { return nil }
        let context = CIContext(options: [.cacheIntermediates: false])
        return context.heifRepresentation(of: mono, format: .RGBA8, colorSpace: space)
    }

    private static func captureIsRaw(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        let head = [UInt8](data.prefix(4))
        let little = head == [0x49, 0x49, 0x2A, 0x00]
        let big = head == [0x4D, 0x4D, 0x00, 0x2A]
        return little || big
    }
}
