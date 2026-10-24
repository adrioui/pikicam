import SwiftUI
import UIKit

/// The entire token table. If a value is not here, it does not exist.
/// Hierarchy is carried by type size, weight of case, and 1px rules —
/// never by color, shadow, radius, blur, or motion.
enum Skin {
    /// Type scale: exactly four sizes, nothing between.
    enum Size {
        case display
        case title
        case body
        case caption

        var points: CGFloat {
            switch self {
            case .display: return 34
            case .title: return 17
            case .body: return 13
            case .caption: return 11
            }
        }
    }

    /// Color: pure black, pure white, one mid-grey for rules. No fourth value.
    enum Ink {
        static let black = Color.black
        static let white = Color.white
        static let rule = Color(white: 0.5)
    }

    /// Rules are 1px hairlines only.
    static let hairline: CGFloat = 1

    /// Targets are at least 44pt; visible marks may be smaller.
    static let targetMinimum: CGFloat = 44

    /// The system monospace at production weight. No brand font files.
    static func mono(_ size: Size) -> Font {
        .system(size: size.points, weight: .regular, design: .monospaced)
    }

    /// Radius 0 everywhere, including system chrome where overridable.
    @MainActor
    static func applyGlobalChrome() {
        let bar = UINavigationBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = .black
        bar.titleTextAttributes = [
            .font: UIFont.monospacedSystemFont(ofSize: Size.caption.points, weight: .regular),
            .foregroundColor: UIColor.white,
        ]
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
    }
}

extension Image {
    func skin(_ size: Skin.Size, _ ink: Color = Skin.Ink.white) -> some View {
        font(Skin.mono(size))
            .foregroundColor(ink)
    }
}

extension Text {
    /// Every label is uppercase text at one of the four sizes.
    func skin(_ size: Skin.Size, _ ink: Color = Skin.Ink.white) -> some View {
        font(Skin.mono(size))
            .foregroundColor(ink)
            .textCase(.uppercase)
    }
}

/// A 1px-ruled, zero-radius control chip. Fill is pure black or pure white.
struct SkinChip: View {
    let title: String
    let size: Skin.Size
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .skin(size, selected ? Skin.Ink.black : Skin.Ink.white)
                .padding(.horizontal, 12)
                .frame(minHeight: Skin.targetMinimum)
                .background(selected ? Skin.Ink.white : Skin.Ink.black)
                .overlay(
                    Rectangle().strokeBorder(selected ? Skin.Ink.white : Skin.Ink.rule, lineWidth: Skin.hairline)
                )
        }
        .buttonStyle(.plain)
    }
}
