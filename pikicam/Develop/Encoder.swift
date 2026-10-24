import CoreImage
import Foundation

enum HEICEncoder {
    static func heic10(from image: CIImage, context: CIContext) throws(DevelopError) -> Rendition? {
        guard let p3 = CGColorSpace(name: CGColorSpace.displayP3) else {
            throw .encodeFailed
        }
        do {
            let data = try context.heif10Representation(of: image, colorSpace: p3, options: [:])
            return rendition(from: image, data: data)
        } catch {
            throw .encodeFailed
        }
    }

    private static func rendition(from image: CIImage, data: Data) -> Rendition? {
        Rendition(
            heic: data,
            pixelSize: CGSize(width: image.extent.width, height: image.extent.height),
            recipeHash: String(NeutralRecipe.version)
        )
    }
}
