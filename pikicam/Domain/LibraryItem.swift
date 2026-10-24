// periphery:ignore
import CoreGraphics
import Foundation

public struct LibraryItem: Hashable, Sendable, Identifiable {
    public let id: AssetID
    public let captureID: CaptureID?
    public let creationDate: Date
    public let mediaKind: MediaKind
    public let developState: DevelopState

    public init(
        id: AssetID,
        captureID: CaptureID?,
        creationDate: Date,
        mediaKind: MediaKind,
        developState: DevelopState
    ) {
        self.id = id
        self.captureID = captureID
        self.creationDate = creationDate
        self.mediaKind = mediaKind
        self.developState = developState
    }
}

public enum MediaKind: Hashable, Sendable {
    case photo
    case video(ClipInfo)
}

public struct ClipInfo: Hashable, Sendable {
    public let clipID: ClipID
    public let duration: Double
    public let mode: VideoMode

    public init(clipID: ClipID, duration: Double, mode: VideoMode) {
        self.clipID = clipID
        self.duration = duration
        self.mode = mode
    }
}

public struct AdjustmentPayload: Codable, Hashable, Sendable {
    public static let formatIdentifier = "piki.pikicam.look"
    public static let formatVersion = "1"

    public let look: LookParameters
    public let geometry: FrameGeometry
    public let recipeVersion: Int
    public let decoderVersion: Int
    public let provenance: Provenance?

    public init(
        look: LookParameters,
        geometry: FrameGeometry,
        recipeVersion: Int,
        decoderVersion: Int,
        provenance: Provenance?
    ) {
        self.look = look
        self.geometry = geometry
        self.recipeVersion = recipeVersion
        self.decoderVersion = decoderVersion
        self.provenance = provenance
    }

    public init(_ entry: JournalEntry, rendition: Rendition?) {
        self.look = entry.look
        self.geometry = entry.geometry
        self.recipeVersion = entry.look.recipeVersion
        self.decoderVersion = entry.look.decoderVersion
        self.provenance = entry.provenance
    }
}

public enum PreviewTarget: Hashable, Sendable {
    case thumbnail(maxPixel: Int)
    case display(pixelSize: CGSize)
}

public struct DisplayImage: Hashable, Sendable {
    public let cgImage: CGImage
    public let pixelSize: CGSize

    public init(cgImage: CGImage, pixelSize: CGSize) {
        self.cgImage = cgImage
        self.pixelSize = pixelSize
    }
}
