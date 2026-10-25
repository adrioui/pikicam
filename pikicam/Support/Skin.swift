import SwiftUI
import UIKit

enum Skin {
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

    enum Ink {
        static let black = Color.black
        static let white = Color.white
        static let rule = Color(white: 0.5)
    }

    static let hairline: CGFloat = 1

    static let targetMinimum: CGFloat = 44

    static func mono(_ size: Size) -> Font {
        .system(size: size.points, weight: .regular, design: .monospaced)
    }

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
    func skin(_ size: Skin.Size, _ ink: Color = Skin.Ink.white) -> some View {
        font(Skin.mono(size))
            .foregroundColor(ink)
            .textCase(.uppercase)
    }
}

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
