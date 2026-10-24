import SwiftUI

enum UGrid {
    static let nano: CGFloat = 4
    static let micro: CGFloat = 8
    static let small: CGFloat = 16
    static let medium: CGFloat = 24
    static let large: CGFloat = 32
    static let hairline: CGFloat = 1
}

enum TypeRole {
    case display
    case headline
    case body
    case telemetry
    case micro

    var size: CGFloat {
        switch self {
        case .display: return 32
        case .headline: return 20
        case .body: return 13
        case .telemetry: return 11
        case .micro: return 9
        }
    }

    var tracking: Double {
        switch self {
        case .display: return -0.04
        case .headline: return 0
        case .body: return 0.01
        case .telemetry: return 0.08
        case .micro: return 0.18
        }
    }

    var weight: Font.Weight {
        switch self {
        case .display, .headline: return .bold
        default: return .regular
        }
    }
}

enum HapticProfile {
    case rigidImpact
    case selection
    case rigidPop
}
