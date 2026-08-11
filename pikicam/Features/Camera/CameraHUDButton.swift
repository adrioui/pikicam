import SwiftUI

/// A translucent round camera-control button (grid / flash / camera flip),
/// matching the pro-camera HUD look (Moment Pro Camera / system Camera):
/// a thin monochrome glyph on a dimmed translucent circle, with a small
/// captioned label beneath for discoverability.
struct CameraHUDButton: View {
    let systemImage: String
    let identifier: String
    let label: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.45), in: Circle())
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

#Preview("HUD buttons") {
    VStack(spacing: 12) {
        CameraHUDButton(
            systemImage: "square.grid.3x3",
            identifier: "grid-toggle",
            label: "Grid",
            value: "On",
            action: {}
        )
        CameraHUDButton(
            systemImage: "bolt.fill",
            identifier: "flash-toggle",
            label: "Flash",
            value: "On",
            action: {}
        )
        CameraHUDButton(
            systemImage: "arrow.triangle.2.circlepath.camera",
            identifier: "front-camera-toggle",
            label: "Camera",
            value: "Back",
            action: {}
        )
    }
    .padding()
    .background(.black)
}
