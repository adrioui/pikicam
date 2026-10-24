import CoreImage
import CoreVideo
import Foundation

enum LinearRenderProbes {
    struct LinearStats {
        var max = 0.0
        var min = Double.greatestFiniteMagnitude
        var mean = 0.0
        var above1 = 0
        var below0 = 0
        var samples = 0
    }

    static func linearStats(of image: CIImage, context: CIContext) -> LinearStats {
        var stats = LinearStats()
        let width = Int(image.extent.width)
        let height = Int(image.extent.height)
        guard width > 0, height > 0,
            let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        else { return stats }
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_64RGBAHalf, nil, &pixelBuffer)
        guard let buffer = pixelBuffer else { return stats }
        context.render(image, to: buffer, bounds: image.extent, colorSpace: colorSpace)

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return stats }
        let stride = CVPixelBufferGetBytesPerRow(buffer) / MemoryLayout<UInt16>.stride
        let pointer = base.assumingMemoryBound(to: UInt16.self)
        var total = 0.0
        var count = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * stride + x * 4
                for c in 0..<3 {
                    let value = Double(Float16(bitPattern: pointer[offset + c]))
                    total += value
                    count += 1
                    if value > stats.max { stats.max = value }
                    if value < stats.min { stats.min = value }
                    if value > 1.0 { stats.above1 += 1 }
                    if value < 0 { stats.below0 += 1 }
                }
            }
        }
        stats.mean = count > 0 ? total / Double(count) : 0
        stats.samples = count
        return stats
    }

    static func edrProbe(data: Data) -> JSONValue {
        guard let filter = CIRAWFilter(imageData: data, identifierHint: "com.adobe.raw-image") else {
            return .dict(["error": "no filter"])
        }
        filter.boostAmount = 0
        filter.boostShadowAmount = 1
        filter.scaleFactor = 0.25
        let context = CIContext()
        var edrs: [JSONValue] = []
        for edr: Float in [0, 1, 2] {
            filter.extendedDynamicRangeAmount = edr
            guard let image = filter.outputImage else {
                edrs.append(.dictionary(["edr": .int(Int(edr)), "outputNil": .bool(true)]))
                continue
            }
            let stats = linearStats(of: image, context: context)
            edrs.append(
                .dictionary([
                    "edr": .int(Int(edr)),
                    "tag": .string(image.colorSpace.map { "\($0)" } ?? "nil"),
                    "max": .double(stats.max),
                    "min": .double(stats.min),
                    "mean": .double(stats.mean),
                    "above1": .int(stats.above1),
                    "below0": .int(stats.below0),
                    "samples": .int(stats.samples),
                ]))
        }
        return .dictionary(["edrLadder": .array(edrs)])
    }

    static func heif10Probe(data: Data) async -> JSONValue {
        guard let filter = CIRAWFilter(imageData: data, identifierHint: "com.adobe.raw-image"),
            let native = filter.outputImage
        else {
            return .dict(["error": "no filter or output"])
        }
        let scaled = native.transformed(by: CGAffineTransform(scaleX: 0.1, y: 0.1))
        guard let p3 = CGColorSpace(name: CGColorSpace.displayP3) else { return .dict(["error": "no P3"]) }
        let context = CIContext(options: [.memoryTarget: 1024])
        do {
            let heic = try await context.heif10Representation(of: scaled, colorSpace: p3, options: [:])
            var out: [String: JSONValue] = ["bytes": .int(heic.count)]
            if let src = CGImageSourceCreateWithData(heic as CFData, nil),
                let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
            {
                out["pixelWidth"] = .int((props[kCGImagePropertyPixelWidth] as? Int) ?? 0)
                out["pixelHeight"] = .int((props[kCGImagePropertyPixelHeight] as? Int) ?? 0)
                out["depth"] = .int((props[kCGImagePropertyDepth] as? Int) ?? 0)
                out["profileName"] = .string((props[kCGImagePropertyProfileName] as? String) ?? "")
            }
            return .dict(out)
        } catch {
            return .dict(["error": "\(error)"])
        }
    }

    static func trapProbe(data: Data) -> JSONValue {
        guard let filter = CIRAWFilter(imageData: data, identifierHint: "com.adobe.raw-image"),
            let image = filter.outputImage
        else {
            return .dict(["error": "no filter or output"])
        }
        let extent = image.extent
        let rowBytes = Int(extent.width) * 8
        guard let buffer = malloc(rowBytes * Int(extent.height)) else {
            return .dict(["error": "malloc failed"])
        }
        defer { free(buffer) }
        if let srgb = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) {
            try? CIContext().render(
                image, toBitmap: buffer, rowBytes: rowBytes,
                bounds: extent, format: .RGBAh, colorSpace: srgb
            )
        }
        return .dict(["survived": true])
    }
}
