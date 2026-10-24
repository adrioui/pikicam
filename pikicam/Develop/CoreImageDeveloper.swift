import CoreImage
import CoreVideo
import Foundation

actor CoreImageDeveloper: Developer {
    private var interactive: CIContext?
    private var export: CIContext?

    private var interactiveContext: CIContext {
        if let interactive { return interactive }
        let workingSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!
        let outputSpace = CGColorSpace(name: CGColorSpace.displayP3)!
        let context = CIContext(options: [
            .workingColorSpace: workingSpace,
            .workingFormat: CIFormat.RGBAh,
            .cacheIntermediates: true,
            .outputColorSpace: outputSpace,
        ])
        interactive = context
        return context
    }

    private var exportContext: CIContext {
        if let export { return export }
        let workingSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!
        let outputSpace = CGColorSpace(name: CGColorSpace.displayP3)!
        let context = CIContext(options: [
            .workingColorSpace: workingSpace,
            .workingFormat: CIFormat.RGBAh,
            .cacheIntermediates: false,
            .memoryTarget: 1024,
            .outputColorSpace: outputSpace,
        ])
        export = context
        return context
    }

    func image(
        _ dng: Data, look: LookParameters, geometry: FrameGeometry, target: PreviewTarget
    ) throws(DevelopError) -> DisplayImage {
        let rendered = try render(
            dng: dng, look: look, geometry: geometry, target: target, context: interactiveContext
        )
        return try displayImage(from: rendered)
    }

    private func displayImage(from rendered: CIImage) throws(DevelopError) -> DisplayImage {
        let p3 = CGColorSpace(name: CGColorSpace.displayP3)!
        guard
            let cg = interactiveContext.createCGImage(rendered, from: rendered.extent, format: .RGBA16, colorSpace: p3)
        else {
            throw .renderFailed
        }
        let size = CGSize(width: rendered.extent.width, height: rendered.extent.height)
        return DisplayImage(cgImage: cg, pixelSize: size)
    }

    func export(_ dng: Data, look: LookParameters, geometry: FrameGeometry) async throws(DevelopError) -> Rendition? {
        let rendered = try render(
            dng: dng, look: look, geometry: geometry, target: .display(pixelSize: .zero), context: exportContext
        )
        return try HEICEncoder.heic10(from: rendered, context: exportContext)
    }

    func inspect(_ dng: Data) throws(DevelopError) -> DNGFacts {
        guard let facts = DNGInspector.facts(from: dng) else {
            throw .undecodable
        }
        return facts
    }

    private func render(
        dng: Data, look: LookParameters, geometry: FrameGeometry, target: PreviewTarget, context: CIContext
    ) throws(DevelopError) -> CIImage {
        guard let filter = CIRAWFilter(imageData: dng, identifierHint: "com.adobe.raw-image"),
            type(of: filter) == CIRAWFilter.self
        else {
            throw .filterUnavailable
        }
        guard NeutralRecipe.pinDecoderVersion(filter) != nil else {
            throw .decoderUnavailable
        }
        _ = NeutralRecipe.apply(to: filter, look: look)
        guard let rawImage = filter.outputImage, filter.nativeSize != .zero else {
            throw .undecodable
        }
        let lookApplied = try PikicamLook.apply(to: rawImage, look: look)
        let cropped = crop(lookApplied, geometry: geometry, filter: filter)
        switch target {
        case .thumbnail(let maxPixel):
            return scaled(cropped, maxPixel: maxPixel, nativeWidth: filter.nativeSize.width)
        case .display:
            return cropped
        }
    }

    private func crop(_ image: CIImage, geometry: FrameGeometry, filter: CIRAWFilter) -> CIImage {
        let pixelRect = geometry.pixelRect(
            for: Int(filter.nativeSize.width), pixelHeight: Int(filter.nativeSize.height)
        )
        let rect = CGRect(
            x: image.extent.minX + pixelRect.minX,
            y: image.extent.minY + pixelRect.minY,
            width: min(pixelRect.width, image.extent.width),
            height: min(pixelRect.height, image.extent.height)
        )
        return image.cropped(to: rect.integral)
    }

    private func scaled(_ image: CIImage, maxPixel: Int, nativeWidth: CGFloat) -> CIImage {
        let longEdge = max(image.extent.width, image.extent.height)
        guard longEdge > CGFloat(maxPixel) else { return image }
        let factor = CGFloat(maxPixel) / longEdge
        return image.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
    }
}
