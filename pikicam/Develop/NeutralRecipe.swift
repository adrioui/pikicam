import CoreImage
import Foundation

public enum NeutralRecipe {
    public static let version = 1

    static func apply(to filter: CIRAWFilter, look: LookParameters) -> RecipeApplication {
        var application = RecipeApplication()
        assign("boostAmount", Float(0), into: &application) { filter.boostAmount = $0 }
        assign("boostShadowAmount", Float(1), into: &application) { filter.boostShadowAmount = $0 }
        assign("shadowBias", Float(0), into: &application) { filter.shadowBias = $0 }
        assign("localToneMapAmount", Float(0), into: &application) { filter.localToneMapAmount = $0 }
        assign("contrastAmount", Float(0), into: &application) { filter.contrastAmount = $0 }
        assign("sharpnessAmount", Float(0), into: &application) { _ in filter.sharpnessAmount = 0 }
        assign("detailAmount", Float(0), into: &application) { filter.detailAmount = $0 }
        assign(
            "luminanceNoiseReductionAmount", Float(0), into: &application
        ) { filter.luminanceNoiseReductionAmount = $0 }
        assign("colorNoiseReductionAmount", Float(0), into: &application) { filter.colorNoiseReductionAmount = $0 }
        assign("moireReductionAmount", Float(0), into: &application) { filter.moireReductionAmount = $0 }
        assign("extendedDynamicRangeAmount", Float(1), into: &application) { filter.extendedDynamicRangeAmount = $0 }
        filter.isLensCorrectionEnabled = false
        application.applied.append("isLensCorrectionEnabled")
        filter.isGamutMappingEnabled = false
        application.applied.append("isGamutMappingEnabled")
        filter.isHighlightRecoveryEnabled = false
        application.applied.append("isHighlightRecoveryEnabled")
        assign("exposure", Float(0), into: &application) { filter.exposure = $0 }

        if !look.whiteBalanceIsAuto {
            filter.neutralTemperature = Float(look.temperature.value)
            filter.neutralTint = Float(look.tint.value)
            application.applied.append("neutralWhiteBalance")
        }
        return application
    }

    static func pinDecoderVersion(_ filter: CIRAWFilter) -> Int? {
        let candidates = filter.supportedDecoderVersions.compactMap { version -> (Int, CIRAWDecoderVersion)? in
            let name = version.rawValue
            guard let prefix = name.split(separator: ".").first, let number = Int(prefix) else {
                return version == .version9 || version == .version9DNG ? nil : (0, version)
            }
            if version == .version9 || version == .version9DNG {
                return nil
            }
            return (number, version)
        }
        guard let highest = candidates.max(by: { $0.0 < $1.0 }) else { return nil }
        filter.decoderVersion = highest.1
        return highest.0
    }

    private static func assign(
        _ name: String, _ value: Float, into application: inout RecipeApplication,
        _ setter: (Float) -> Void
    ) {
        setter(value)
        application.applied.append(name)
    }
}
