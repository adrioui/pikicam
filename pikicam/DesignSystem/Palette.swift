import SwiftUI

enum Palette {
    static let gesso = Color(hex: 0xFFFFFF)
    static let muslin = Color(hex: 0xF4F3EF)
    static let calico = Color(hex: 0xD6D3CB)
    static let ash = Color(hex: 0x888681)
    static let carbon = Color(hex: 0x262524)
    static let photometricBlack = Color(hex: 0x080808)
}

enum SurfaceColor {
    static let surface = Color(hex: 0x0E0E0E)
    static let low = Color(hex: 0x141414)
    static let card = Color(hex: 0x181818)
    static let elevated = Color(hex: 0x222222)
}

enum RuleColor {
    static let border = Color(hex: 0x2A2A2A)
    static let borderLight = Color(hex: 0x3C3C3C)
}

enum TextColor {
    static let primary = Color(hex: 0xF8F7F4)
    static let muted = Color(hex: 0x9E9E9C)
    static let dim = Color(hex: 0x6B6A68)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
