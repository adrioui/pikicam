import SwiftUI

struct NumericLineMatrix: View {
    let active: Int?
    let dormantNumbers: Set<Int>
    let onSelect: (Int) -> Void

    private let numbers = Array(0...23)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: [GridItem(.fixed(36))], spacing: UGrid.nano) {
                ForEach(numbers, id: \.self) { number in
                    cell(number)
                }
            }
            .padding(.horizontal, UGrid.micro)
        }
        .frame(height: 44)
        .accessibilityIdentifier(AccessibilityID.Camera.lineMatrix)
    }

    @ViewBuilder
    private func cell(_ number: Int) -> some View {
        let isActive = number == active
        if dormantNumbers.contains(number) {
            Text("\(number)")
                .font(PikicamFont.mono(.body))
                .foregroundStyle(TextColor.dim.opacity(0.5))
                .frame(width: 36, height: 36)
                .accessibilityLabel("Line \(number), dormant")
        } else {
            Button {
                onSelect(number)
            } label: {
                Text("\(number)")
                    .font(PikicamFont.mono(.body))
                    .foregroundStyle(isActive ? Palette.photometricBlack : TextColor.muted)
                    .frame(width: 36, height: 36)
                    .background(isActive ? Palette.gesso : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Line \(number)")
            .accessibilityAddTraits(isActive ? [.isSelected] : [])
        }
    }
}
