import AVFoundation
import SwiftUI

// MARK: - CameraView

/// Full-screen camera: live preview, shutter, and a top-right HUD cluster
/// of quick toggles (RAW, grid, flash, self-timer, camera flip).
struct CameraView: View {
    @Environment(CameraViewModel.self) private var viewModel
    @State private var session: AVCaptureSession?
    @State private var zoomGestureBase: CGFloat = 1.0

    var body: some View {
        ZStack {
            preview
            controls
        }
        .overlay {
            if let review = viewModel.lastReviewResult {
                ReviewOverlay(
                    jpegData: review.jpegData,
                    captureZoom: review.captureZoom,
                    timestamp: review.timestamp,
                    onDismiss: { viewModel.clearReview() }
                )
            }
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
            session = await viewModel.captureService.getSession().session
        }
        .onDisappear {
            Task { await viewModel.stop() }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var preview: some View {
        if let session {
            CameraPreview(session: session)
                .ignoresSafeArea()
                .accessibilityIdentifier("preview-pinch-area")
        } else {
            Color.black.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 0) {
            if viewModel.isConfigured {
                HUDCluster
                Spacer()
                VolumeButtonCaptureView {
                    if !viewModel.isCapturing && viewModel.isConfigured {
                        Task { await viewModel.capture() }
                    }
                }
                .frame(width: 0, height: 0)
                ZoomIndicatorView(factor: viewModel.zoomFactor)
                    .padding(.bottom, 8)
            } else {
                Spacer()
            }
            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .accessibilityLabel("Error: \(error.localizedDescription)")
            }
            if viewModel.isConfigured {
                if viewModel.selfTimerRemaining > 0 {
                    SelfTimerCountdownView(remaining: viewModel.selfTimerRemaining)
                }
                ShutterButton(
                    isCapturing: viewModel.isCapturing,
                    action: { Task { await viewModel.capture() } }
                )
                .padding(.bottom, 32)
            }
        }
    }

    @ViewBuilder
    private var HUDCluster: some View {
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
                    systemImage: viewModel.selfTimer == .off
                        ? "timer" : "timer.circle.fill",
                    identifier: "self-timer-toggle",
                    label: "Timer",
                    value: viewModel.selfTimer.label,
                    action: { viewModel.cycleSelfTimer() }
                )
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

    private var flashIcon: String {
        switch viewModel.flashMode {
        case .off: return "bolt.slash"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic"
        }
    }

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

// MARK: - ReviewOverlay

/// Shows the just-captured print above the live preview. Non-blocking
/// (`.allowsHitTesting(false)`) so the shutter and HUD stay tappable,
/// and self-dismisses after a few seconds.
private struct ReviewOverlay: View {
    let jpegData: Data
    let captureZoom: CGFloat
    let timestamp: Date
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
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
        .allowsHitTesting(false)
        .task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { onDismiss() }
        }
        .accessibilityIdentifier("review-overlay")
    }
}

// MARK: - SelfTimerCountdownView

/// Big centered number shown while the self-timer counts down. Doubles as
/// the cancel target — tapping anywhere on the screen cancels via the VM.
private struct SelfTimerCountdownView: View {
    let remaining: Int

    var body: some View {
        Text("\(remaining)")
            .font(.system(size: 96, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(24)
            .background(.black.opacity(0.6))
            .clipShape(Circle())
            .accessibilityIdentifier("self-timer-countdown")
    }
}
