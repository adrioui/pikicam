// periphery:ignore
import CoreGraphics
import Foundation

public struct ScanConfig: Hashable, Sendable {
    public enum Axis: String, Hashable, Sendable, CaseIterable {
        case horizontal
        case vertical
        case movingSlit

        public var label: String {
            switch self {
            case .horizontal: return "H"
            case .vertical: return "V"
            case .movingSlit: return "MS"
            }
        }
    }

    public let axis: Axis
    public let slitWidth: Int
    public let outputLength: Int
    public let frameRate: Double

    public static let allowedSlitWidths: [Int] = [1, 2, 4, 8, 16]

    public init(axis: Axis, slitWidth: Int, outputLength: Int, frameRate: Double) {
        self.axis = axis
        self.slitWidth = Self.allowedSlitWidths.contains(slitWidth) ? slitWidth : 8
        self.outputLength = outputLength
        self.frameRate = frameRate
    }

    public var estimatedDuration: Double {
        Double(outputLength) / (Double(slitWidth) * frameRate)
    }
}

public struct ScanResult: Hashable, Sendable {
    public let id: CaptureID
    public let assemblyBytes: Data
    public let width: Int
    public let height: Int
    public let config: ScanConfig
    public let frameCount: Int
    public let droppedFrames: Int
    public let duration: Double
    public let isPartial: Bool

    public init(
        id: CaptureID,
        assemblyBytes: Data,
        width: Int,
        height: Int,
        config: ScanConfig,
        frameCount: Int,
        droppedFrames: Int,
        duration: Double,
        isPartial: Bool
    ) {
        self.id = id
        self.assemblyBytes = assemblyBytes
        self.width = width
        self.height = height
        self.config = config
        self.frameCount = frameCount
        self.droppedFrames = droppedFrames
        self.duration = duration
        self.isPartial = isPartial
    }

    public var dropPercent: Double {
        frameCount > 0 ? Double(droppedFrames) * 100 / Double(frameCount) : 0
    }
}
