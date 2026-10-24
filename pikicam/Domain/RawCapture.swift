// periphery:ignore
import Foundation

public struct RawCapture: Hashable, Sendable {
    public let id: CaptureID
    public let dng: Data
    public let provenance: Provenance

    public init(id: CaptureID, dng: Data, provenance: Provenance) {
        self.id = id
        self.dng = dng
        self.provenance = provenance
    }
}

public struct DNGFacts: Hashable, Sendable {
    public enum Photometric: UInt16, Hashable, Sendable {
        case cfa = 32803
        case linearRaw = 34892
    }

    public let isTIFF: Bool
    public let dngVersion: String?
    public let photometricInterpretation: Photometric?
    public let hasCFATags: Bool
    public let uniqueCameraModel: String?
    public let orientation: Int?
    public let baselineExposure: Double?
    public let asShotNeutral: [Double]?
    public let width: Int
    public let height: Int
}
