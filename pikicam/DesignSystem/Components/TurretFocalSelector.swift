import SwiftUI

struct TurretFocalSelector: View {
    let lenses: [Lens]
    let selected: LensKind
    let onSelect: (LensKind) -> Void

    var body: some View {
        HStack(spacing: UGrid.hairline) {
            ForEach(lenses, id: \.uniqueID) { lens in
                cell(lens)
            }
        }
        .padding(UGrid.nano)
        .background(Palette.photometricBlack)
        .overlay(RuleColor.border.frame(height: UGrid.hairline), alignment: .top)
        .overlay(RuleColor.border.frame(height: UGrid.hairline), alignment: .bottom)
    }

    @ViewBuilder
    private func cell(_ lens: Lens) -> some View {
        let isSelected = lens.kind == selected
        let multiplier = Self.multiplier(for: lens)
        Button {
            onSelect(lens.kind)
        } label: {
            HStack(spacing: UGrid.nano) {
                Text(multiplier)
                    .font(PikicamFont.mono(.body))
                Text("\(lens.equivalentFocalLength)MM")
                    .font(PikicamFont.mono(.micro))
                    .foregroundStyle(isSelected ? Palette.photometricBlack : TextColor.dim)
            }
            .foregroundStyle(isSelected ? Palette.photometricBlack : TextColor.muted)
            .padding(.horizontal, UGrid.small)
            .frame(minHeight: 44)
            .background(isSelected ? Palette.gesso : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("camera.lens.\(lens.kind.rawValue)")
        .accessibilityLabel("\(lens.equivalentFocalLength) millimetre lens")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    static func multiplier(for lens: Lens) -> String {
        switch lens.kind {
        case .ultraWide: return ".5"
        case .wide: return "1x"
        case .telephoto: return "3x"
        }
    }
}
