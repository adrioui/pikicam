// periphery:ignore
import Foundation

public struct MonoWeights: Hashable, Codable, Sendable {
    public let r: Float
    public let g: Float
    public let b: Float

    public init?(validating r: Float, g: Float, b: Float) {
        guard r >= 0, g >= 0, b >= 0 else { return nil }
        let sum = r + g + b
        guard abs(sum - 1.0) <= 1e-5 else { return nil }
        self.r = r
        self.g = g
        self.b = b
    }
}

public enum MonoPreset: String, Hashable, Codable, Sendable, CaseIterable {
    case neutral
    case yellow
    case orange
    case red
    case green
    case blue

    public var weights: MonoWeights {
        switch self {
        case .neutral: return MonoWeights(validating: 0.22897, g: 0.69174, b: 0.07929)!
        case .yellow: return MonoWeights(validating: 0.30, g: 0.70, b: 0.00)!
        case .orange: return MonoWeights(validating: 0.45, g: 0.55, b: 0.00)!
        case .red: return MonoWeights(validating: 0.85, g: 0.15, b: 0.00)!
        case .green: return MonoWeights(validating: 0.05, g: 0.90, b: 0.05)!
        case .blue: return MonoWeights(validating: 0.05, g: 0.15, b: 0.80)!
        }
    }

    public var rationale: String {
        switch self {
        case .neutral: return "Luminance row of the linear Display-P3 to XYZ matrix"
        case .yellow: return "Wratten 8: passes R+G, absorbs B"
        case .orange: return "Wratten 15: deep sky darkening, balanced skin"
        case .red: return "Wratten 25: maximum red contrast, black sky"
        case .green: return "Wratten 58: foliage tonal separation"
        case .blue: return "Wratten 47: blue sensitivity, haze rendering"
        }
    }
}

public struct MonoState: Hashable, Codable, Sendable {
    public let preset: MonoPreset
    public let custom: MonoWeights?

    public init(preset: MonoPreset, custom: MonoWeights? = nil) {
        self.preset = preset
        self.custom = custom
    }

    public var activeWeights: MonoWeights {
        custom ?? preset.weights
    }
}
