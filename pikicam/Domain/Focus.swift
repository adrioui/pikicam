// periphery:ignore
import Foundation

public enum FocusMode: Hashable, Sendable {
    case continuousAuto
    case auto(point: NormalizedPoint)
    case locked(lensPosition: LensPosition)
}

public enum ExposureMode: Hashable, Sendable {
    case auto(bias: EV)
    case manual(iso: ISO, duration: ShutterSpeed)
}

public enum LightMode: String, Hashable, Sendable, CaseIterable {
    case off
    case torch
    case flash

    public var label: String {
        switch self {
        case .off: return "OFF"
        case .torch: return "TORCH"
        case .flash: return "FLASH"
        }
    }
}
