import SwiftUI

struct TactileCalibrationDial: View {
    let steps: [String]
    @Binding var active: Int
    let parameterName: String

    var body: some View {
        VStack(spacing: UGrid.small) {
            HStack {
                Text("PARAMETER: \(parameterName)")
                    .font(PikicamFont.mono(.body))
                    .foregroundStyle(TextColor.dim)
                Spacer()
                Text(steps[active])
                    .font(PikicamFont.mono(.body))
                    .foregroundStyle(TextColor.primary)
            }
            ZStack {
                needle
                HStack(spacing: UGrid.medium) {
                    ForEach(steps.indices, id: \.self) { index in
                        tick(index)
                    }
                }
            }
            .frame(height: 48)
            .clipped()
            Slider(value: Binding(
                get: { Double(active) },
                set: { newValue in
                    let stepped = Int(newValue.rounded())
                    if stepped != active {
                        active = stepped
                    }
                }
            ), in: 0...Double(max(steps.count - 1, 0)), step: 1)
            .tint(Palette.gesso)
            .accessibilityLabel("\(parameterName) dial")
            .accessibilityValue(steps[active])
        }
    }

    private var needle: some View {
        Rectangle()
            .fill(Palette.gesso)
            .frame(width: 2)
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func tick(_ index: Int) -> some View {
        let isMajor = index % 3 == 0
        let isCenter = index == active
        VStack(spacing: UGrid.nano) {
            Rectangle()
                .fill(isCenter ? Palette.gesso : (isMajor ? TextColor.muted : TextColor.dim))
                .frame(width: isCenter ? 2 : 1, height: isCenter ? 24 : (isMajor ? 16 : 8))
            if isMajor {
                Text(steps[index])
                    .font(PikicamFont.mono(.micro))
                    .foregroundStyle(isCenter ? TextColor.primary : TextColor.muted)
            }
        }
    }
}
