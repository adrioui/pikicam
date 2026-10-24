// periphery:ignore
import SwiftUI

enum UGrid {
    static let nano: CGFloat = 4
    static let micro: CGFloat = 8
    static let small: CGFloat = 16
    static let medium: CGFloat = 24
    static let large: CGFloat = 32
    static let hairline: CGFloat = 1
}

enum UMotion {
    static let snap: Double = 0
    static let drawer: Double = 120
    static let focusSnap: Double = 60

    static func duration(for named: String, reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : rawDuration(named)
    }

    private static func rawDuration(_ named: String) -> Double {
        switch named {
        case "drawer": return drawer
        case "focusSnap": return focusSnap
        default: return snap
        }
    }
}

enum MinTouchTarget {
    static let control: CGFloat = 44
    static let shutter: CGFloat = 88
}

enum TypeRole {
    case display
    case title
    case readout
    case label
    case micro

    var size: CGFloat {
        switch self {
        case .display: return 18
        case .title: return 13
        case .readout: return 11
        case .label: return 10
        case .micro: return 9
        }
    }

    var tracking: Double {
        switch self {
        case .display: return -0.03
        case .title: return -0.02
        case .readout: return 0.08
        case .label, .micro: return 0.18
        }
    }

    var weight: Font.Weight {
        switch self {
        case .display, .title: return .bold
        default: return .regular
        }
    }
}
