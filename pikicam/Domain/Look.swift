// periphery:ignore
import Foundation

public struct LookParameters: Codable, Hashable, Sendable {
    public var exposureEV: Double
    public var temperature: Kelvin
    public var tint: Tint
    public var whiteBalanceIsAuto: Bool
    public var contrast: Double
    public var highlights: Double
    public var shadows: Double
    public var mono: MonoState?
    public var line: Int?
    public var recipeVersion: Int
    public var decoderVersion: Int

    public init(
        exposureEV: Double = 0,
        temperature: Kelvin = Kelvin(5600),
        tint: Tint = Tint(0),
        whiteBalanceIsAuto: Bool = true,
        contrast: Double = 0,
        highlights: Double = 0,
        shadows: Double = 0,
        mono: MonoState? = nil,
        line: Int? = nil,
        recipeVersion: Int = NeutralRecipe.version,
        decoderVersion: Int = 0
    ) {
        self.exposureEV = exposureEV
        self.temperature = temperature
        self.tint = tint
        self.whiteBalanceIsAuto = whiteBalanceIsAuto
        self.contrast = contrast
        self.highlights = highlights
        self.shadows = shadows
        self.mono = mono
        self.line = line
        self.recipeVersion = recipeVersion
        self.decoderVersion = decoderVersion
    }

    public static let standard = LookParameters()
}

public struct RecipeApplication: Codable, Hashable, Sendable {
    public var applied: [String]
    public var unsupported: [String]
    public var defaultsDiffering: [String]

    public init(applied: [String] = [], unsupported: [String] = [], defaultsDiffering: [String] = []) {
        self.applied = applied
        self.unsupported = unsupported
        self.defaultsDiffering = defaultsDiffering
    }

    public var isComplete: Bool { unsupported.isEmpty }
}

public struct DecoderVersion: Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let version9 = DecoderVersion(rawValue: 9)
    public static let version9DNG = DecoderVersion(rawValue: 10)

    public var isLegacy: Bool { self == .version9 || self == .version9DNG }
}

public struct Rendition: Hashable, Sendable {
    public let heic: Data
    public let pixelSize: CGSize
    public let recipeHash: String

    public init(heic: Data, pixelSize: CGSize, recipeHash: String) {
        self.heic = heic
        self.pixelSize = pixelSize
        self.recipeHash = recipeHash
    }
}

public struct LineProfile: Hashable, Sendable {
    public let number: Int
    public let name: String
    public let look: LookParameters?
    public let mono: MonoState?
    public let bindsLens: LensKind?
    public let isDormant: Bool
    public let dormantReason: String?

    public init(
        number: Int,
        name: String,
        look: LookParameters?,
        mono: MonoState?,
        bindsLens: LensKind? = nil,
        isDormant: Bool = false,
        dormantReason: String? = nil
    ) {
        self.number = number
        self.name = name
        self.look = look
        self.mono = mono
        self.bindsLens = bindsLens
        self.isDormant = isDormant
        self.dormantReason = dormantReason
    }
}

extension LineProfile {
    public static let table: [LineProfile] = [
        LineProfile(number: 0, name: "Artisanal", look: .standard, mono: nil),
        LineProfile(number: 1, name: "Softer", look: LookParameters(contrast: -0.25, shadows: 0.15), mono: nil),
        LineProfile(
            number: 3, name: "Fragrance", look: nil, mono: nil, isDormant: true,
            dormantReason: "Reserved; no distinct look in this pipeline version"),
        LineProfile(number: 4, name: "Artisanal (alias)", look: .standard, mono: nil),
        LineProfile(number: 10, name: "Harder", look: LookParameters(contrast: 0.3, highlights: -0.2), mono: nil),
        LineProfile(
            number: 11, name: "Telephoto", look: nil, mono: nil, bindsLens: .telephoto,
            isDormant: true, dormantReason: "This device has no telephoto lens"
        ),
        LineProfile(number: 14, name: "HP5", look: nil, mono: MonoState(preset: .neutral)),
        LineProfile(number: 22, name: "Level Lock", look: nil, mono: nil),
        LineProfile(
            number: 23, name: "Reserve", look: nil, mono: nil,
            isDormant: true, dormantReason: "Reserved; no binding in this pipeline version"
        ),
    ]

    public static func line(_ number: Int) -> LineProfile? {
        table.first { $0.number == number }
    }
}
