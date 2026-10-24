// periphery:ignore
import Foundation

public enum SessionState: Hashable, Sendable {
    case idle
    case configuring
    case running(LensKind)
    case interrupted(reason: String)
    case unavailable(reason: String)
    case failed(CaptureError)
}

public enum ShutterState: Hashable, Sendable {
    case ready
    case pressed
    case countdown(remaining: Int)
    case capturing(CaptureID)
    case saving(CaptureID)
    case failed(CameraError)
}

public enum RecordingState: Hashable, Sendable {
    case idle
    case requesting
    case recording(since: Date)
    case stopping
    case failed(RecordingError)
}

public enum ScanState: Hashable, Sendable {
    case idle
    case scanning(progress: Double, since: Date)
    case finishing
    case failed(ScanError)
}

public enum PermissionState: Hashable, Sendable {
    case notDetermined
    case granted
    case denied
    case limited
    case restricted
}

public enum DevelopState: Hashable, Sendable {
    case developed
    case pending
    case failed(DevelopError)
}

public enum ThermalState: Hashable, Sendable {
    case nominal
    case fair
    case serious
    case critical
}
