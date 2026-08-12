import AVFoundation
import SwiftUI

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
    @State private var zoomGestureBase: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Live camera preview
            if let session {
                CameraPreview(session: session)
                    .ignoresSafeArea()
                    .accessibilityIdentifier("preview-pinch-area")
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Top-right control cluster: grid, flash, camera flip.
                if viewModel.isConfigured {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            CameraHUDButton(
                                systemImage: viewModel.isRAWEnabled ? "camera.fill" : "camera",
                                identifier: "raw-toggle",
                                label: "RAW",
                                value: viewModel.isRAWEnabled ? "On" : "Off",
                                action: { viewModel.toggleRAW() }
                            )
                            CameraHUDButton(
                                systemImage: viewModel.showsGrid
                                    ? "square.grid.3x3.fill" : "square.grid.3x3",
                                identifier: "grid-toggle",
                                label: "Grid",
                                value: viewModel.showsGrid ? "On" : "Off",
                                action: { viewModel.toggleGrid() }
                            )
                            if viewModel.flashAvailable {
                                CameraHUDButton(
                                    systemImage: flashIcon,
                                    identifier: "flash-toggle",
                                    label: "Flash",
                                    value: viewModel.flashMode.label,
                                    action: { Task { await viewModel.cycleFlash() } }
                                )
                            }
                            CameraHUDButton(
                                systemImage: "arrow.triangle.2.circlepath.camera",
                                identifier: "front-camera-toggle",
                                label: "Camera",
                                value: viewModel.cameraPosition.label,
                                action: { Task { await viewModel.toggleCamera() } }
                            )
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 8)
                    }
                }

                Spacer()

                // Hidden volume-button trigger: hardware sound buttons fire capture.
                VolumeButtonCaptureView {
                    if !viewModel.isCapturing && viewModel.isConfigured {
                        Task { await viewModel.capture() }
                    }
                }
                .frame(width: 0, height: 0)

                if viewModel.isConfigured {
                    // Current zoom factor, e.g. "1.0x".
                    ZoomIndicatorView(factor: viewModel.zoomFactor)
                        .padding(.bottom, 8)
                }

                // Minimal, non-blocking error feedback.
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .accessibilityLabel("Error: \(error.localizedDescription)")
                }

                if viewModel.isConfigured {
                    // The shutter release. Hardware volume buttons also
                    // trigger a capture (VolumeButtonCaptureView above).
                    ShutterButton(
                        isCapturing: viewModel.isCapturing,
                        action: {
                            Task { await viewModel.capture() }
                        }
                    )
                    .padding(.bottom, 32)
                }
            }
        }
        .overlay {
            if let review = viewModel.lastReviewResult {
                ReviewOverlay(
                    jpegData: review.jpegData,
                    captureZoom: review.zoomFactor,
                    timestamp: review.timestamp,
                    onDismiss: { viewModel.clearReview() }
                )
            }
            // 3×3 framing grid on top of the preview but under the controls.
            if viewModel.isConfigured {
                GridOverlayView(showsGrid: viewModel.showsGrid)
                    .ignoresSafeArea()
            }
        }
        .gesture(pinchGesture)
        .onChange(of: viewModel.cameraPosition) { _, _ in
            zoomGestureBase = 1.0
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

    /// The flash button icon for the current mode.
    private var flashIcon: String {
        switch viewModel.flashMode {
        case .off: return "bolt.slash"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic"
        }
    }

    /// Pinch-to-zoom: the gesture's scale is applied on top of the zoom
    /// factor the gesture started from, so repeated pinches accumulate.
    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let factor = ZoomMath.factor(
                    base: zoomGestureBase,
                    magnification: value,
                    range: viewModel.zoomRange
                )
                Task { await viewModel.setZoom(factor) }
            }
            .onEnded { _ in
                zoomGestureBase = viewModel.zoomFactor
            }
    }
}

#Preview {
    CameraView()
        .environment(CameraViewModel())
}

// MARK: - Post-Capture Review (inline best-practice: avoids extra pbxproj file)
private struct ReviewOverlay: View {
    let jpegData: Data
    let captureZoom: CGFloat
    let timestamp: Date
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image = UIImage(data: jpegData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            }
            VStack {
                Spacer()
                HStack(spacing: 16) {
                    Text(String(format: "%.1fx", captureZoom))
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                    Text(timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                }
                .padding(.bottom, 32)
            }
        }
        .onTapGesture { onDismiss() }
    }
}
