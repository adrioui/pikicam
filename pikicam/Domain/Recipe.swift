// periphery:ignore
import Foundation

public enum NeutralRecipe {
    public static let version = 1

    public struct Values: Hashable, Sendable {
        public var boostAmount: Float = 0
        public var boostShadowAmount: Float = 1
        public var shadowBias: Float = 0
        public var localToneMapAmount: Float = 0
        public var contrastAmount: Float = 0
        public var sharpnessAmount: Float = 0
        public var detailAmount: Float = 0
        public var luminanceNoiseReductionAmount: Float = 0
        public var colorNoiseReductionAmount: Float = 0
        public var moireReductionAmount: Float = 0
        public var extendedDynamicRangeAmount: Float = 1
        public var isLensCorrectionEnabled = false
        public var isGamutMappingEnabled = false
        public var isHighlightRecoveryEnabled = false
        public var exposure: Float = 0
        public var baselineExposureIsTagValue = true

        public init() {}
    }

    public static let neutral = Values()
}
