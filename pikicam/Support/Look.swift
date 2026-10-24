import CoreImage
import Foundation

/// One look for both domains. The mono row is DERIVED (CIE P3 primaries,
/// D65 — scripts/p3-luminance.py prints these constants); a unit test
/// recomputes the derivation and fails if this row drifts.
enum Look {
    static let luminanceRow = (r: 0.22897, g: 0.69174, b: 0.07929)

    /// The tone definition: display-native. No additional grading is
    /// applied in either domain — the delivered transfer is the display's.
    /// Stated so there is exactly one tone definition, and it is this one.
    static func apply(to image: CIImage, mono: Bool) -> CIImage {
        guard mono else { return image }
        return image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: luminanceRow.r, y: luminanceRow.g, z: luminanceRow.b, w: 0),
            "inputGVector": CIVector(x: luminanceRow.r, y: luminanceRow.g, z: luminanceRow.b, w: 0),
            "inputBVector": CIVector(x: luminanceRow.r, y: luminanceRow.g, z: luminanceRow.b, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0),
        ])
    }

    static func monochromeHEIC(from data: Data) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            render(data: data)
        }.value
    }

    private static func render(data: Data) -> Data? {
        let image: CIImage
        if data.looksLikeTIFF {
            guard let filter = CIRAWFilter(imageData: data, identifierHint: "com.adobe.raw-image") else {
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
        let mono = apply(to: image, mono: true)
        guard let space = CGColorSpace(name: CGColorSpace.displayP3) else { return nil }
        return CIContext(options: [.cacheIntermediates: false])
            .heifRepresentation(of: mono, format: .RGBA8, colorSpace: space)
    }
}

extension Data {
    var looksLikeTIFF: Bool {
        guard count >= 4 else { return false }
        let head = [UInt8](prefix(4))
        return head == [0x49, 0x49, 0x2A, 0x00] || head == [0x4D, 0x4D, 0x00, 0x2A]
    }
}
