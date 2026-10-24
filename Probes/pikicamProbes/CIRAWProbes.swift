import CoreImage
import CoreVideo
import Foundation
import UniformTypeIdentifiers

enum CIRAWProbes {
    static func loadFixture() -> Data? {
        guard let url = Bundle.main.url(forResource: "IMG_1361", withExtension: "DNG") else { return nil }
        return try? Data(contentsOf: url)
    }

    static func initProbe(data: Data) -> JSONValue {
        let modern = CIRAWFilter(imageData: data, identifierHint: "com.adobe.raw-image")
        var out: [String: JSONValue] = [:]
        out["modernClass"] = modern.map { .string("\(type(of: $0))") } ?? .string("nil")
        out["modernIsCIRAWFilterClass"] = .bool(modern.map { type(of: $0) == CIRAWFilter.self } ?? false)
        if let modern {
            out["modernSupportedDecoderVersions"] = .array(modern.supportedDecoderVersions.map { .string("\($0.rawValue)") })
            out["modernNativeSize"] = .string("\(modern.nativeSize.width)x\(modern.nativeSize.height)")
            out["modernOutputNotNil"] = .bool(modern.outputImage != nil)
            out["staticSupportedCameraModelsCount"] = .int(CIRAWFilter.supportedCameraModels.count)
            out["staticModelsContainThisDevice"] = .bool(
                CIRAWFilter.supportedCameraModels.contains { $0.contains("iPhone13,1") }
            )
        }
        return .dict(out)
    }

    static func deprecatedInitProbe(data: Data) -> JSONValue {
        let stub = CIRAWFilter(imageData: data)
        var out: [String: JSONValue] = [:]
        out["runtimeClass"] = stub.map { .string("\(type(of: $0))") } ?? .string("nil")
        out["isaTopIsCIRAWFilter"] = .bool(stub.map { type(of: $0) == CIRAWFilter.self } ?? false)
        if let stub {
            out["respondsToBoostSetter"] = .bool(stub.responds(to: Selector(("setBoostAmount:"))))
            out["respondsToHighlightRecoverySetter"] = .bool(stub.responds(to: Selector(("setIsHighlightRecoveryEnabled:"))))
            out["respondsToDecoderVersionSetter"] = .bool(stub.responds(to: Selector(("setDecoderVersion:"))))
        }
        return .dict(out)
    }

    struct ControlSpec {
        let name: String
        let neutral: String
        let assign: (CIRAWFilter) -> Void
        let readback: (CIRAWFilter) -> String
    }

    static func controlSpecs() -> [ControlSpec] {
        [
            ControlSpec(name: "boostAmount", neutral: "0.0",
                        assign: { $0.boostAmount = 0 }, readback: { "\(String(format: "%.4f", $0.boostAmount))" }),
            ControlSpec(name: "boostShadowAmount", neutral: "1.0",
                        assign: { $0.boostShadowAmount = 1 }, readback: { "\(String(format: "%.4f", $0.boostShadowAmount))" }),
            ControlSpec(name: "shadowBias", neutral: "0.0",
                        assign: { $0.shadowBias = 0 }, readback: { "\(String(format: "%.4f", $0.shadowBias))" }),
            ControlSpec(name: "localToneMapAmount", neutral: "0.0",
                        assign: { $0.localToneMapAmount = 0 }, readback: { "\(String(format: "%.4f", $0.localToneMapAmount))" }),
            ControlSpec(name: "contrastAmount", neutral: "0.0",
                        assign: { $0.contrastAmount = 0 }, readback: { "\(String(format: "%.4f", $0.contrastAmount))" }),
            ControlSpec(name: "sharpnessAmount", neutral: "0.0",
                        assign: { $0.sharpnessAmount = 0 }, readback: { "\(String(format: "%.4f", $0.sharpnessAmount))" }),
            ControlSpec(name: "detailAmount", neutral: "0.0",
                        assign: { $0.detailAmount = 0 }, readback: { "\(String(format: "%.4f", $0.detailAmount))" }),
            ControlSpec(name: "luminanceNoiseReductionAmount", neutral: "0.0",
                        assign: { $0.luminanceNoiseReductionAmount = 0 }, readback: { "\(String(format: "%.4f", $0.luminanceNoiseReductionAmount))" }),
            ControlSpec(name: "colorNoiseReductionAmount", neutral: "0.0",
                        assign: { $0.colorNoiseReductionAmount = 0 }, readback: { "\(String(format: "%.4f", $0.colorNoiseReductionAmount))" }),
            ControlSpec(name: "moireReductionAmount", neutral: "0.0",
                        assign: { $0.moireReductionAmount = 0 }, readback: { "\(String(format: "%.4f", $0.moireReductionAmount))" }),
            ControlSpec(name: "extendedDynamicRangeAmount", neutral: "1",
                        assign: { $0.extendedDynamicRangeAmount = 1 }, readback: { "\($0.extendedDynamicRangeAmount)" }),
            ControlSpec(name: "isLensCorrectionEnabled", neutral: "false",
                        assign: { $0.isLensCorrectionEnabled = false }, readback: { "\($0.isLensCorrectionEnabled)" }),
            ControlSpec(name: "isGamutMappingEnabled", neutral: "false",
                        assign: { $0.isGamutMappingEnabled = false }, readback: { "\($0.isGamutMappingEnabled)" }),
            ControlSpec(name: "exposure", neutral: "0.0",
                        assign: { $0.exposure = 0 }, readback: { "\(String(format: "%.4f", $0.exposure))" }),
        ]
    }

    static func controlReadbackProbe(data: Data) -> JSONValue {
        guard let filter = CIRAWFilter(imageData: data, identifierHint: "com.adobe.raw-image"),
              type(of: filter) == CIRAWFilter.self else {
            return .dict(["error": "filter not real CIRAWFilter"])
        }
        var out: [String: JSONValue] = [:]
        out["decoderVersions"] = .array(filter.supportedDecoderVersions.map { .string("\($0.rawValue)") })

        let chosen = filter.supportedDecoderVersions
            .filter { $0 != .version9 && $0 != .version9DNG }
            .map { $0.rawValue }.max()
        if let chosen {
            filter.decoderVersion = CIRAWDecoderVersion(rawValue: chosen)
            out["decoderVersionSet"] = .string("\(chosen)")
            out["decoderVersionReadback"] = .string("\(filter.decoderVersion.rawValue)")
        }

        var controls: [JSONValue] = []
        for spec in controlSpecs() {
            let exception = PIKExceptionCatcher.catchException {
                spec.assign(filter)
            }
            controls.append(.dict([
                "name": spec.name,
                "assigned": exception == nil,
                "exception": exception?.name ?? "",
                "readback": spec.readback(filter),
                "neutral": spec.neutral,
            ]))
        }
        out["controls"] = .array(controls)

        let hrEx = PIKExceptionCatcher.catchException { filter.isHighlightRecoveryEnabled = false }
        out["highlightRecoveryAssigned"] = .bool(hrEx == nil)
        out["highlightRecoveryReadback"] = .string("\(filter.isHighlightRecoveryEnabled)")
        out["baselineExposureDefault"] = .string("\(filter.baselineExposure)")
        out["neutralTemperatureDefault"] = .string("\(filter.neutralTemperature)")
        out["neutralTintDefault"] = .string("\(filter.neutralTint)")
        out["orientationDefault"] = .string("\(filter.orientation.rawValue)")
        out["scaleFactorDefault"] = .string("\(filter.scaleFactor)")
        out["isDraftModeEnabledDefault"] = .string("\(filter.isDraftModeEnabled)")
        return .dict(out)
    }

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
              let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3) else { return stats }
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
            edrs.append(.dictionary([
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
              let native = filter.outputImage else {
            return .dict(["error": "no filter or output"])
        }
        let scaled = native.transformed(by: CGAffineTransform(scaleX: 0.1, y: 0.1))
        guard let p3 = CGColorSpace(name: CGColorSpace.displayP3) else { return .dict(["error": "no P3"]) }
        let context = CIContext(options: [.memoryTarget: 1024])
        do {
            let heic = try await context.heif10Representation(of: scaled, colorSpace: p3, options: [:])
            var out: [String: JSONValue] = ["bytes": .int(heic.count)]
            if let src = CGImageSourceCreateWithData(heic as CFData, nil),
               let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
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
              let image = filter.outputImage else {
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
