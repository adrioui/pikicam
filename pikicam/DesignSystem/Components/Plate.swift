import SwiftUI

struct BracketButton: View {
    let title: String
    var accessibilityID: String = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PikicamFont.mono(.telemetry))
                .foregroundStyle(Palette.calico)
                .padding(.horizontal, UGrid.micro)
                .frame(minWidth: 44, minHeight: 44)
                .background(RuleColor.border.frame(height: UGrid.hairline), alignment: .top)
                .overlay(RuleColor.border.frame(height: UGrid.hairline), alignment: .bottom)
                .overlay(RuleColor.border.frame(width: UGrid.hairline), alignment: .leading)
                .overlay(RuleColor.border.frame(width: UGrid.hairline), alignment: .trailing)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(accessibilityID)
        .accessibilityLabel(title)
    }
}

struct ErrorBanner: View {
    let title: String
    let detail: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: UGrid.nano) {
            Text(title)
                .font(PikicamFont.mono(.telemetry))
                .foregroundStyle(Palette.gesso)
            Text(detail)
                .font(PikicamFont.mono(.micro))
                .foregroundStyle(Palette.calico)
            Button(action: onDismiss) {
                Text("[ DISMISS ]")
                    .font(PikicamFont.mono(.micro))
                    .foregroundStyle(Palette.gesso)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Dismiss error")
        }
        .padding(UGrid.micro)
        .background(SurfaceColor.low)
        .overlay(RuleColor.border.frame(height: UGrid.hairline), alignment: .top)
    }
}
