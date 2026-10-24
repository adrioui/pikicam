// periphery:ignore
import Foundation

public struct ISO: Hashable, Sendable, Comparable {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public init(clamping raw: Double, to limits: ClosedRange<Double>) {
        self.value = saturate(raw, into: limits)
    }

    public static func < (lhs: ISO, rhs: ISO) -> Bool { lhs.value < rhs.value }
}

func saturate(_ value: Double, into limits: ClosedRange<Double>) -> Double {
    if value.isNaN {
        return limits.lowerBound
    }
    if value == .infinity {
        return limits.upperBound
    }
    if value == -.infinity {
        return limits.lowerBound
    }
    return min(max(value, limits.lowerBound), limits.upperBound)
}

public struct ShutterSpeed: Hashable, Sendable, Comparable {
    public let seconds: Double

    public init(seconds: Double) {
        self.seconds = seconds
    }

    public init(clamping seconds: Double, to limits: ClosedRange<Double>) {
        self.seconds = saturate(seconds, into: limits)
    }

    public static func < (lhs: ShutterSpeed, rhs: ShutterSpeed) -> Bool {
        lhs.seconds < rhs.seconds
    }

    public var label: String {
        if seconds >= 1 {
            return String(format: "%.0f\"", seconds)
        }
        let denominator = Int((1 / seconds).rounded())
        return "1/\(denominator)"
    }
}

public struct EV: Hashable, Sendable {
    public let value: Double

    public init(_ value: Double) {
        self.value = value
    }

    public static let step: Double = 1.0 / 3.0
    public static let range: ClosedRange<Double> = -8.0...8.0

    public init(clamping raw: Double) {
        let snapped = raw.isNaN ? 0 : (raw / Self.step).rounded() * Self.step
        self.value = saturate(snapped, into: Self.range)
    }
}

public struct LensPosition: Hashable, Sendable {
    public let value: Float

    public static let range: ClosedRange<Float> = 0.0...1.0

    public init(_ value: Float) {
        self.value = value
    }

    public init(clamping raw: Float) {
        if raw.isNaN || raw == -.infinity {
            self.value = Self.range.lowerBound
        } else if raw == .infinity {
            self.value = Self.range.upperBound
        } else {
            self.value = min(max(raw, Self.range.lowerBound), Self.range.upperBound)
        }
    }
}

public struct NormalizedPoint: Hashable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x.isNaN || x.isInfinite ? 0.5 : min(max(x, 0), 1)
        self.y = y.isNaN || y.isInfinite ? 0.5 : min(max(y, 0), 1)
    }
}
