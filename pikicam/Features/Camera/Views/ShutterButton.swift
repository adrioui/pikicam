import SwiftUI

/// The main shutter release button.
///
/// Mimics the system Camera app's shutter button appearance and behavior.
/// Dims while a capture is in progress.
struct ShutterButton: View {
    let isCapturing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring
                Circle()
                    .strokeBorder(.white, lineWidth: 4)
                    .frame(width: 80, height: 80)

                // Inner fill
                Circle()
                    .fill(.white)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Circle()
                            .fill(.black)
                            .frame(width: 56, height: 56)
                            .opacity(isCapturing ? 0.3 : 0)
                    }
            }
        }
        .disabled(isCapturing)
        .buttonStyle(.shutter)
        .accessibilityLabel("Capture photo")
    }
}

/// Custom button style for the shutter button press animation.
private struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ShutterButtonStyle {
    static var shutter: ShutterButtonStyle { ShutterButtonStyle() }
}

#Preview {
    ShutterButton(isCapturing: false, action: {})
        .frame(width: 200, height: 200)
        .background(.black)
}
