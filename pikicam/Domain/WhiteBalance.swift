// periphery:ignore
import Foundation

public struct Kelvin: Hashable, Codable, Sendable, Comparable {
    public let value: Int

    public static let range: ClosedRange<Int> = 2000...10000

    public init(_ value: Int) {
        self.value = value
    }

    public init(clamping raw: Int) {
        self.value = min(max(raw, Self.range.lowerBound), Self.range.upperBound)
    }

    public static func < (lhs: Kelvin, rhs: Kelvin) -> Bool { lhs.value < rhs.value }
}

public struct Tint: Hashable, Codable, Sendable, Comparable {
    public let value: Int

    public static let range: ClosedRange<Int> = -150...150

    public init(_ value: Int) {
        self.value = value
    }

    public init(clamping raw: Int) {
        self.value = min(max(raw, Self.range.lowerBound), Self.range.upperBound)
    }

    public static func < (lhs: Tint, rhs: Tint) -> Bool { lhs.value < rhs.value }
}

public enum WhiteBalanceMode: Hashable, Sendable {
    case auto
    case lockedCurrent
    case locked(Kelvin, Tint)
}
