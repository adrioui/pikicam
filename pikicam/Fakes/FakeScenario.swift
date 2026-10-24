// periphery:ignore
import Foundation

#if DEBUG

    enum FakeScenario: String, Sendable {
        case standard
        case emptyLibrary
        case developFails
        case saveFailsTransient
        case storageFull
        case recorderFails
        case scanStalls
        case deniedPermissions
    }

#endif
