import CoreImage
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Extension providing raw development utilities for `CIImage`.
extension CIImage {
    /// Returns the image's extent as a human-readable string.
    var extentDescription: String {
        "\(Int(extent.width))×\(Int(extent.height))"
    }

    /// Returns a quick-rendered JPEG thumbnail suitable for previews.
    /// - Parameter maxDimension: The maximum dimension for the thumbnail.
    /// - Returns: JPEG data, or `nil` if rendering fails.
    func thumbnailJPEG(maxDimension: CGFloat = 480) -> Data? {
        let scale = min(maxDimension / extent.width, maxDimension / extent.height, 1.0)
        let scaledWidth = Int(extent.width * scale)
        let scaledHeight = Int(extent.height * scale)

        guard scaledWidth > 0, scaledHeight > 0 else { return nil }

        let context = CIContext(options: [
            .priorityRequestLow: true,
            .cacheIntermediates: false,
        ])

        guard let cgImage = context.createCGImage(self, from: extent) else {
            return nil
        }

        // Create a downscaled bitmap context
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue

        guard let bitmapContext = CGContext(
            data: nil,
            width: scaledWidth,
            height: scaledHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        bitmapContext.interpolationQuality = .high
        bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))

        guard let downscaled = bitmapContext.makeImage() else { return nil }

        // Encode to JPEG via CGImageDestination
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.8
        ]

        CGImageDestinationAddImage(destination, downscaled, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return data as Data
    }
}
