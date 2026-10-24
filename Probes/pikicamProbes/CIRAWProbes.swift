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
            out["modernSupportedDecoderVersions"] = .array(
                modern.supportedDecoderVersions.map { .string("\($0.rawValue)") })
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
            out["respondsToHighlightRecoverySetter"] = .bool(
                stub.responds(to: Selector(("setIsHighlightRecoveryEnabled:"))))
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
        amountControls() + neutralFlagControls()
    }

    private static func sp(
        _ name: String, neutral: String,
        assign: @escaping (CIRAWFilter) -> Void, read: @escaping (CIRAWFilter) -> String
    ) -> ControlSpec {
        ControlSpec(name: name, neutral: neutral, assign: assign, readback: read)
    }

    private static func amountControls() -> [ControlSpec] {
        [
            sp("boostAmount", neutral: "0.0") {
                $0.boostAmount = 0
            } read: {
                fmt($0.boostAmount)
            },
            sp("boostShadowAmount", neutral: "1.0") {
                $0.boostShadowAmount = 1
            } read: {
                fmt($0.boostShadowAmount)
            },
            sp("shadowBias", neutral: "0.0") {
                $0.shadowBias = 0
            } read: {
                fmt($0.shadowBias)
            },
            sp("localToneMapAmount", neutral: "0.0") {
                $0.localToneMapAmount = 0
            } read: {
                fmt($0.localToneMapAmount)
            },
            sp("contrastAmount", neutral: "0.0") {
                $0.contrastAmount = 0
            } read: {
                fmt($0.contrastAmount)
            },
            sp("sharpnessAmount", neutral: "0.0") {
                $0.sharpnessAmount = 0
            } read: {
                fmt($0.sharpnessAmount)
            },
            sp("detailAmount", neutral: "0.0") {
                $0.detailAmount = 0
            } read: {
                fmt($0.detailAmount)
            },
        ]
    }

    private static func neutralFlagControls() -> [ControlSpec] {
        [
            ControlSpec(
                name: "luminanceNoiseReductionAmount", neutral: "0.0",
                assign: { $0.luminanceNoiseReductionAmount = 0 }, readback: { fmt($0.luminanceNoiseReductionAmount) }
            ),
            ControlSpec(
                name: "colorNoiseReductionAmount", neutral: "0.0",
                assign: { $0.colorNoiseReductionAmount = 0 }, readback: { fmt($0.colorNoiseReductionAmount) }
            ),
            ControlSpec(
                name: "moireReductionAmount", neutral: "0.0",
                assign: { $0.moireReductionAmount = 0 }, readback: { fmt($0.moireReductionAmount) }
            ),
            ControlSpec(
                name: "extendedDynamicRangeAmount", neutral: "1",
                assign: { $0.extendedDynamicRangeAmount = 1 }, readback: { "\($0.extendedDynamicRangeAmount)" }
            ),
            ControlSpec(
                name: "isLensCorrectionEnabled", neutral: "false",
                assign: { $0.isLensCorrectionEnabled = false }, readback: { "\($0.isLensCorrectionEnabled)" }
            ),
            ControlSpec(
                name: "isGamutMappingEnabled", neutral: "false",
                assign: { $0.isGamutMappingEnabled = false }, readback: { "\($0.isGamutMappingEnabled)" }
            ),
            ControlSpec(name: "exposure", neutral: "0.0", assign: { $0.exposure = 0 }, readback: { fmt($0.exposure) }),
        ]
    }

    private static func fmt(_ value: Float) -> String {
        String(format: "%.4f", value)
    }

    static func controlReadbackProbe(data: Data) -> JSONValue {
        guard let filter = CIRAWFilter(imageData: data, identifierHint: "com.adobe.raw-image"),
            type(of: filter) == CIRAWFilter.self
        else {
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
            controls.append(
                .dict([
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
}
