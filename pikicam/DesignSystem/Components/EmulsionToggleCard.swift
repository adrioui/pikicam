import SwiftUI

struct EmulsionToggleCard: View {
    let title: String
    let telemetryTag: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: UGrid.small) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: UGrid.nano) {
                    Text("FUNCTION")
                        .font(PikicamFont.mono(.micro))
                        .foregroundStyle(TextColor.dim)
                    Text(title)
                        .font(PikicamFont.mono(.body))
                        .foregroundStyle(TextColor.primary)
                }
                Spacer()
                Text(telemetryTag)
                    .font(PikicamFont.mono(.micro))
                    .foregroundStyle(TextColor.muted)
                    .padding(.horizontal, UGrid.nano)
                    .background(SurfaceColor.elevated)
            }
            Divider().overlay(RuleColor.border)
            HStack {
                Text(isOn ? "ENGAGED" : "BYPASS")
                    .font(PikicamFont.mono(.telemetry))
                    .foregroundStyle(isOn ? TextColor.primary : TextColor.dim)
                Spacer()
                rocker
            }
        }
        .padding(UGrid.small)
        .background(SurfaceColor.low)
        .overlay(RuleColor.border.frame(height: UGrid.hairline), alignment: .top)
        .overlay(RuleColor.border.frame(height: UGrid.hairline), alignment: .bottom)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "Engaged" : "Bypass")
        .accessibilityAddTraits(.isButton)
        .onTapGesture { isOn.toggle() }
    }

    private var rocker: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Rectangle()
                .fill(isOn ? Palette.gesso : SurfaceColor.elevated)
                .frame(width: 48, height: 24)
            Rectangle()
                .fill(isOn ? Palette.photometricBlack : TextColor.dim)
                .frame(width: 20, height: 20)
                .padding(2)
        }
        .animation(.linear(duration: 0), value: isOn)
    }
}
