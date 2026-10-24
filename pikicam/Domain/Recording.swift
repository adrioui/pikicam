// periphery:ignore
import Foundation

public enum VideoMode: String, Hashable, Sendable, CaseIterable {
    case res1080p30
    case res1080p60
    case res2160p30
    case proRes422HQ
}

public struct RecordingIntent: Hashable, Sendable {
    public var mode: VideoMode
    public var audio: Bool

    public init(mode: VideoMode, audio: Bool) {
        self.mode = mode
        self.audio = audio
    }
}

public struct VideoClip: Hashable, Sendable {
    public let id: ClipID
    public let originalURL: URL
    public let renditionURL: URL
    public let mode: VideoMode
    public let duration: Double
    public let droppedFrames: Int
    public let provenanceEvents: [ProvenanceEvent]

    public init(
        id: ClipID,
        originalURL: URL,
        renditionURL: URL,
        mode: VideoMode,
        duration: Double,
        droppedFrames: Int,
        provenanceEvents: [ProvenanceEvent]
    ) {
        self.id = id
        self.originalURL = originalURL
        self.renditionURL = renditionURL
        self.mode = mode
        self.duration = duration
        self.droppedFrames = droppedFrames
        self.provenanceEvents = provenanceEvents
    }
}

public struct ProvenanceEvent: Codable, Hashable, Sendable {
    public let timestamp: Double
    public let kind: String
    public let detail: String

    public init(timestamp: Double, kind: String, detail: String) {
        self.timestamp = timestamp
        self.kind = kind
        self.detail = detail
    }
}
