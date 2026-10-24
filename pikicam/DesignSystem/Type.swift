import SwiftUI
import UIKit

enum PikicamFont {
    static func mono(_ role: TypeRole) -> Font {
        Font.custom("SpaceMono-Regular", size: role.size).weight(role.weight)
    }

    static func monoBold(_ role: TypeRole) -> Font {
        Font.custom("SpaceMono-Bold", size: role.size)
    }

    static func uiFont(_ role: TypeRole) -> UIFont? {
        UIFont(name: "SpaceMono-Regular", size: role.size)
    }
}

extension Text {
    func pikicamType(_ role: TypeRole) -> some View {
        font(PikicamFont.mono(role))
            .tracking(role.tracking)
            .textCase(uppercase(for: role))
    }

    private func uppercase(for role: TypeRole) -> Text.Case? {
        switch role {
        case .telemetry, .micro: return .uppercase
        default: return nil
        }
    }
}
