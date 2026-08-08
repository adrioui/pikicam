import SwiftUI
import AVFoundation

// MARK: - CameraView

/// The main camera interface.
///
/// MVP design: a full-screen live preview with a single shutter button.
/// Tapping it captures one pure Bayer RAW frame, develops it with all
/// computational-photography processing disabled, and saves the resulting
/// print alongside the untouched DNG to the user's Photos library.
struct CameraView: View {
    @Environment(CameraViewModel.self) private var viewModel
    @State private var session: AVCaptureSession?

    var body: some View {
        ZStack {
            // Live camera preview
            if let session {
                CameraPreview(session: session)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack {
                Spacer()

                // Minimal, non-blocking error feedback.
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .accessibilityLabel("Error: \(error.localizedDescription)")
                }

                // The only control in the MVP: the shutter button.
                ShutterButton(
                    isCapturing: viewModel.isCapturing,
                    action: {
                        Task { await viewModel.capture() }
                    }
                )
                .padding(.bottom, 32)
            }
        }
        .task {
            await viewModel.start()
            let sessionBox = await viewModel.captureService.getSession()
            session = sessionBox.session
        }
        .onDisappear {
            Task { await viewModel.stop() }
        }
    }
}

#Preview {
    CameraView()
        .environment(CameraViewModel())
}
