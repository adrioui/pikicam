// periphery:ignore
import Foundation

public enum JournalPhase: String, Codable, Hashable, Sendable {
    case captured
    case developed
    case saved
}

public struct JournalEntry: Codable, Hashable, Sendable {
    public let id: CaptureID
    public let capturedAt: Date
    public let phase: JournalPhase
    public let geometry: FrameGeometry
    public let look: LookParameters
    public let provenance: Provenance

    public init(
        id: CaptureID,
        capturedAt: Date,
        phase: JournalPhase,
        geometry: FrameGeometry,
        look: LookParameters,
        provenance: Provenance
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.phase = phase
        self.geometry = geometry
        self.look = look
        self.provenance = provenance
    }
}

public struct RetryPolicy<E: Error>: Sendable {
    public let attempts: Int
    public let backoff: [Double]

    public init(attempts: Int, backoff: [Double]) {
        self.attempts = attempts
        self.backoff = backoff
    }

    public static func photosSave() -> RetryPolicy<E> {
        RetryPolicy(attempts: 3, backoff: [0.5, 1, 2])
    }
}
