import SwiftUI

struct CareLabelStrip: View {
    struct Telemetry {
        let focal: Int
        let aperture: String
        let shutter: String
        let iso: Int
        let kelvin: Int
    }

    let telemetry: Telemetry

    var body: some View {
        VStack(alignment: .leading, spacing: UGrid.nano) {
            seam
            HStack(spacing: UGrid.small) {
                Text("[\(telemetry.focal)MM WIDE]")
                Text("·").foregroundStyle(TextColor.dim)
                Text(telemetry.aperture)
                Text("·").foregroundStyle(TextColor.dim)
                Text(telemetry.shutter)
                Text("·").foregroundStyle(TextColor.dim)
                Text("ISO \(telemetry.iso)")
                Text("·").foregroundStyle(TextColor.dim)
                Text("\(telemetry.kelvin)K")
            }
            .font(PikicamFont.mono(.body))
            .foregroundStyle(TextColor.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            seam
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.Camera.readoutRail)
    }

    private var seam: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, Palette.gesso.opacity(0.4), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(height: UGrid.hairline)
    }
}
