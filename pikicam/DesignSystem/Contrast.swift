import CoreGraphics
import Foundation

struct ContrastPair: Sendable {
    let foreground: UInt32
    let background: UInt32
    let minimum: Double
    let name: String
}

enum Contrast {
    static func relativeLuminance(_ hex: UInt32) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        let lighter = max(la, lb)
        let darker = min(la, lb)
        return (lighter + 0.05) / (darker + 0.05)
    }

    static let textPairs: [ContrastPair] = [
        ContrastPair(foreground: 0xF4F3EF, background: 0x080808, minimum: 4.5, name: "muslin on photometricDeep"),
        ContrastPair(foreground: 0xD6D3CB, background: 0x141312, minimum: 4.5, name: "calico on photometricLow"),
        ContrastPair(foreground: 0x888681, background: 0x080808, minimum: 4.5, name: "ash on photometricDeep"),
        ContrastPair(foreground: 0x080808, background: 0xFFFFFF, minimum: 4.5, name: "photometricDeep on gesso"),
        ContrastPair(foreground: 0x262524, background: 0xF4F3EF, minimum: 4.5, name: "carbon on muslin"),
    ]

    static let nonTextPairs: [ContrastPair] = [
        ContrastPair(foreground: 0xFFFFFF, background: 0x262524, minimum: 3.0, name: "gesso rule on carbon plate"),
        ContrastPair(foreground: 0x888681, background: 0x141312, minimum: 3.0, name: "ash tick on photometricLow"),
    ]
}
