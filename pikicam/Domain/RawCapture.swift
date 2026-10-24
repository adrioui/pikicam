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

    public var isTIFF: Bool
    public var dngVersion: String?
    public var photometricInterpretation: Photometric?
    public var hasCFATags: Bool
    public var uniqueCameraModel: String?
    public var orientation: Int?
    public var baselineExposure: Double?
    public var asShotNeutral: [Double]?
    public var width: Int
    public var height: Int

    public init(
        isTIFF: Bool, dngVersion: String?, photometricInterpretation: Photometric?, hasCFATags: Bool,
        uniqueCameraModel: String?, orientation: Int?, baselineExposure: Double?, asShotNeutral: [Double]?,
        width: Int, height: Int
    ) {
        self.isTIFF = isTIFF
        self.dngVersion = dngVersion
        self.photometricInterpretation = photometricInterpretation
        self.hasCFATags = hasCFATags
        self.uniqueCameraModel = uniqueCameraModel
        self.orientation = orientation
        self.baselineExposure = baselineExposure
        self.asShotNeutral = asShotNeutral
        self.width = width
        self.height = height
    }
}
