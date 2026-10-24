// periphery:ignore
import CoreGraphics
import Foundation

public struct ExposureLimits: Hashable, Sendable {
    public let iso: ClosedRange<Double>
    public let exposureDuration: ClosedRange<Double>
    public let bias: ClosedRange<Double>

    public init(iso: ClosedRange<Double>, exposureDuration: ClosedRange<Double>, bias: ClosedRange<Double>) {
        self.iso = iso
        self.exposureDuration = exposureDuration
        self.bias = bias
    }
}

public struct WhiteBalanceLimits: Hashable, Sendable {
    public let temperature: ClosedRange<Int>
    public let tint: ClosedRange<Int>
    public let maxGain: Double

    public init(temperature: ClosedRange<Int>, tint: ClosedRange<Int>, maxGain: Double) {
        self.temperature = temperature
        self.tint = tint
        self.maxGain = maxGain
    }
}

public struct DeviceCapabilities: Hashable, Sendable {
    public let lenses: [Lens]
    public let exposureLimits: [LensKind: ExposureLimits]
    public let whiteBalanceLimits: WhiteBalanceLimits
    public let flashSupported: Bool
    public let focusLockSupported: Bool
    public let rawDimensions: CGSize
    public let bayerFormat: BayerFormat

    public init(
        lenses: [Lens],
        exposureLimits: [LensKind: ExposureLimits],
        whiteBalanceLimits: WhiteBalanceLimits,
        flashSupported: Bool,
        focusLockSupported: Bool,
        rawDimensions: CGSize,
        bayerFormat: BayerFormat
    ) {
        self.lenses = lenses
        self.exposureLimits = exposureLimits
        self.whiteBalanceLimits = whiteBalanceLimits
        self.flashSupported = flashSupported
        self.focusLockSupported = focusLockSupported
        self.rawDimensions = rawDimensions
        self.bayerFormat = bayerFormat
    }

    public func lens(_ kind: LensKind) -> Lens? {
        lenses.first { $0.kind == kind }
    }
}

public enum DeterminismValue: String, Hashable, Codable, Sendable {
    case off
    case notSupported
    case on
}

public struct DeviceDeterminism: Hashable, Codable, Sendable {
    public var geometricDistortionCorrection: DeterminismValue
    public var centerStage: DeterminismValue
    public var videoHDR: DeterminismValue
    public var lowLightBoost: DeterminismValue
    public var colorSpace: String

    public init(
        geometricDistortionCorrection: DeterminismValue,
        centerStage: DeterminismValue,
        videoHDR: DeterminismValue,
        lowLightBoost: DeterminismValue,
        colorSpace: String
    ) {
        self.geometricDistortionCorrection = geometricDistortionCorrection
        self.centerStage = centerStage
        self.videoHDR = videoHDR
        self.lowLightBoost = lowLightBoost
        self.colorSpace = colorSpace
    }
}

public struct DeviceReadings: Hashable, Sendable {
    public let iso: Double
    public let exposureDuration: Double
    public let lensPosition: Float
    public let whiteBalanceGains: [Double]

    public init(iso: Double, exposureDuration: Double, lensPosition: Float, whiteBalanceGains: [Double]) {
        self.iso = iso
        self.exposureDuration = exposureDuration
        self.lensPosition = lensPosition
        self.whiteBalanceGains = whiteBalanceGains
    }
}

public struct MeterReading: Hashable, Sendable {
    public let histogram: [Int]
    public let clippedLow: Int
    public let clippedHigh: Int

    public init(histogram: [Int], clippedLow: Int, clippedHigh: Int) {
        self.histogram = histogram
        self.clippedLow = clippedLow
        self.clippedHigh = clippedHigh
    }
}

public struct LevelReading: Hashable, Sendable {
    public let rollDegrees: Double
    public let pitchDegrees: Double

    public init(rollDegrees: Double, pitchDegrees: Double) {
        self.rollDegrees = rollDegrees
        self.pitchDegrees = pitchDegrees
    }

    public var isLevel: Bool {
        abs(rollDegrees) <= 1 && abs(pitchDegrees) <= 1
    }
}
