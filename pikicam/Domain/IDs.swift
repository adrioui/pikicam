// periphery:ignore
import Foundation

public struct CaptureID: Hashable, Codable, Sendable, Identifiable, CustomStringConvertible {
    public let id: UUID

    public init() {
        self.id = UUID()
    }

    public init(_ id: UUID) {
        self.id = id
    }

    public var description: String { id.uuidString }
}

public struct AssetID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let localIdentifier: String

    public init(localIdentifier: String) {
        self.localIdentifier = localIdentifier
    }

    public var description: String { localIdentifier }
}

public struct ClipID: Hashable, Codable, Sendable, Identifiable, CustomStringConvertible {
    public let id: UUID

    public init() {
        self.id = UUID()
    }

    public init(_ id: UUID) {
        self.id = id
    }

    public var description: String { id.uuidString }
}

public enum LensKind: String, Hashable, Codable, Sendable, CaseIterable {
    case ultraWide
    case wide
    case telephoto
}

public struct Lens: Hashable, Sendable {
    public let kind: LensKind
    public let uniqueID: String
    public let equivalentFocalLength: Int

    public init(kind: LensKind, uniqueID: String, equivalentFocalLength: Int) {
        self.kind = kind
        self.uniqueID = uniqueID
        self.equivalentFocalLength = equivalentFocalLength
    }
}

public struct BayerFormat: Hashable, Sendable {
    public let osType: OSType

    public init(osType: OSType) {
        self.osType = osType
    }

    public var fourCC: String {
        let bytes = [
            UInt8((osType >> 24) & 0xFF),
            UInt8((osType >> 16) & 0xFF),
            UInt8((osType >> 8) & 0xFF),
            UInt8(osType & 0xFF),
        ]
        return String(bytes.map { Character(UnicodeScalar($0)) })
    }
}
