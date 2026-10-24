import SwiftUI

struct ArchiveRollSummary: View {
    let rollNumber: Int
    let date: Date
    let payload: String
    let lineName: String
    let thumbnail: UIImage?
    let onInspect: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: UGrid.small) {
            pinnedThumbnail
            VStack(alignment: .leading, spacing: UGrid.nano) {
                Text("CAPTURE DOSSIER")
                    .font(PikicamFont.mono(.micro))
                    .foregroundStyle(TextColor.dim)
                Text("ARCHIVE ROLL #\(String(format: "%04d", rollNumber))")
                    .font(PikicamFont.mono(.headline))
                    .foregroundStyle(TextColor.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                    Text("PAYLOAD: \(payload)")
                    Text("CALIBRATION: \(lineName)")
                }
                .font(PikicamFont.mono(.telemetry))
                .foregroundStyle(TextColor.muted)
                Button(action: onInspect) {
                    Text("INSPECT RAW DOSSIER ↗")
                        .font(PikicamFont.mono(.telemetry))
                        .foregroundStyle(Palette.photometricBlack)
                        .padding(.horizontal, UGrid.small)
                        .padding(.vertical, UGrid.nano)
                        .background(Palette.gesso)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
        }
        .padding(UGrid.small)
        .background(SurfaceColor.low)
        .overlay(RuleColor.border.frame(height: UGrid.hairline), alignment: .top)
        .overlay(RuleColor.border.frame(height: UGrid.hairline), alignment: .bottom)
        .accessibilityElement(children: .combine)
    }

    private var pinnedThumbnail: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Palette.photometricBlack)
                .frame(width: 96, height: 96)
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 90, height: 90)
                    .clipped()
                    .saturation(0)
                    .contrast(1.25)
                    .padding(3)
            }
            stitch
        }
        .overlay(RuleColor.border.frame(height: UGrid.hairline), alignment: .top)
        .frame(width: 96, height: 96)
    }

    private var stitch: some View {
        VStack(alignment: .leading, spacing: 1) {
            Rectangle().fill(Palette.gesso).frame(width: 10, height: 1.5)
            Rectangle().fill(Palette.gesso).frame(width: 1.5, height: 10)
        }
        .padding(4)
    }
}
