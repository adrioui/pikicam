// periphery:ignore
import SwiftUI

enum Palette {
    static let gesso = Color(hex: 0xFFFFFF)
    static let muslin = Color(hex: 0xF4F3EF)
    static let calico = Color(hex: 0xD6D3CB)
    static let ash = Color(hex: 0x888681)
    static let carbon = Color(hex: 0x262524)
    static let photometricLow = Color(hex: 0x141312)
    static let photometricDeep = Color(hex: 0x080808)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    init(uiHex hex: UInt32) {
        self.init(hex: hex)
    }
}

enum PlateColor {
    static let photometricLow = Color(hex: 0x141312)
    static let photometricDeep = Color(hex: 0x080808)
    static let carbon = Color(hex: 0x262524)
}

enum InkColor {
    static let gesso = Color(hex: 0xFFFFFF)
    static let muslin = Color(hex: 0xF4F3EF)
    static let calico = Color(hex: 0xD6D3CB)
    static let ash = Color(hex: 0x888681)
}
