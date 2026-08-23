import AVFoundation
import SwiftUI

// MARK: - CameraView

/// Full-screen camera: live preview, shutter, and a top-right HUD cluster
/// of quick toggles (grid, flash, self-timer, camera flip) plus a 4:3 /
/// 16:9 / 1:1 aspect strip.
struct CameraView: View {
    @Environment(CameraViewModel.self) private var viewModel
    @Environment(PikicamLibraryModel.self) private var library
    @State private var session: AVCaptureSession?
    @State private var zoomGestureBase: CGFloat = 1.0
    @State private var lastGestureFactor: CGFloat = 1.0
    @State private var galleryPresented = false
    /// Whether the exposure-compensation slider is over the preview. It
    /// appears with each tap-to-meter and auto-dismisses after a short idle.
    @State private var showsExposureSlider = false
    @State private var sliderDismissTask: Task<Void, Never>?
    /// The continuous slider value while dragging; committed to the view
    /// model (snapped to 1/3 stops) when the drag ends.
    @State private var exposureDraftStops: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            preview
            controls
        }
        .overlay {
            if viewModel.isConfigured {
                FramingOverlays(
                    showsGrid: viewModel.showsGrid,
                    aspectRatio: viewModel.aspectRatio
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .trailing) {
            if viewModel.isConfigured,
               showsExposureSlider,
               viewModel.phase == .idle {
                ExposureSliderView(stops: $exposureDraftStops) {
                    let committed = ExposureCompensation(stops: exposureDraftStops)
                    Task { await viewModel.setExposureCompensation(committed) }
                }
                .frame(height: 220)
                .padding(.trailing, 14)
                .padding(.bottom, 120)
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $galleryPresented) {
            GalleryView()
                .environment(library)
        }
        .gesture(pinchGesture)
        .onChange(of: viewModel.cameraPosition) { _, _ in
            zoomGestureBase = 1.0
            lastGestureFactor = 1.0
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
            CameraPreview(
                session: session,
                onTap: { point in
                    presentExposureSlider()
                    Task { await viewModel.setFocusAndExposure(at: point) }
                }
            )
            .ignoresSafeArea()
            .accessibilityIdentifier("preview-pinch-area")
        } else {
            Color.black.ignoresSafeArea()
        }
    }

    /// Shows the EV slider and restarts its auto-dismiss clock. Each new
    /// tap-to-meter re-presents it; 2.5 s of idleness hides it again.
    private func presentExposureSlider() {
        sliderDismissTask?.cancel()
        exposureDraftStops = viewModel.exposureCompensation.stops
        withAnimation(.easeInOut(duration: 0.2)) { showsExposureSlider = true }
        sliderDismissTask = Task {
            try? await Task.sleep(for: .milliseconds(2500))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) { showsExposureSlider = false }
        }
    }

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 0) {
            if viewModel.isConfigured {
                HUDCluster
            } else {
                Spacer()
            }

            Spacer()

            if viewModel.selfTimerRemaining > 0 {
                SelfTimerCountdownView(remaining: viewModel.selfTimerRemaining) {
                    // A tap during the countdown cancels the whole capture
                    // (countdown task + the capture it was about to start).
                    viewModel.capture()
                }
            }

            if viewModel.isConfigured {
                Spacer()

                // Zoom preset chips
                HStack(spacing: 12) {
                    ForEach(ZoomPresets.factors(in: viewModel.zoomRange), id: \.self) { preset in
                        Button {
                            Task { await viewModel.setZoom(preset) }
                        } label: {
                            Text(ZoomMath.label(for: preset))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    ZoomPresets.isSelected(viewModel.zoomFactor, of: preset)
                                        ? Color.black : Color.white
                                )
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    ZoomPresets.isSelected(viewModel.zoomFactor, of: preset)
                                        ? Color.yellow : Color.black.opacity(0.5)
                                )
                                .clipShape(Capsule())
                        }
                        .accessibilityIdentifier("zoom-preset-\(ZoomMath.label(for: preset))")
                    }
                }
                .padding(.bottom, 10)

                // Aspect ratio strip
                HStack(spacing: 16) {
                    Spacer()
                    ForEach(AspectRatio.allCases, id: \.self) { ratio in
                        Button(action: { viewModel.setAspectRatio(ratio) }) {
                            Text(ratio.label)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(viewModel.aspectRatio == ratio ? .yellow : .black.opacity(0.5))
                                .clipShape(Capsule())
                        }
                        .accessibilityIdentifier("mode-\(ratio.rawValue)")
                    }
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 8)

                // Bottom dock
                HStack(alignment: .bottom) {
                    // Thumbnail (lower-left)
                    Button {
                        galleryPresented = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 60, height: 58)
                            if let capture = library.captures.first {
                                ThumbnailImage(assetID: capture.assetID, library: library)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(width: 60, height: 58)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                                .padding(2)
                        }
                    }
                    .accessibilityIdentifier("gallery-thumbnail")

                    Spacer()

                    // Shutter (center)
                    ShutterButton(
                        isCapturing: viewModel.phase == .capturing || viewModel.phase == .savingDNG,
                        action: viewModel.capture
                    )

                    Spacer()

                    // Flip (lower-right)
                    CameraHUDButton(
                        systemImage: "arrow.triangle.2.circlepath.camera",
                        identifier: "front-camera-toggle",
                        label: "Camera",
                        value: viewModel.cameraPosition.label,
                        action: { Task { await viewModel.toggleCamera() } }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)

                // Hidden volume-button capture
                VolumeButtonCaptureView {
                    if viewModel.isConfigured {
                        viewModel.capture()
                    }
                }
                .frame(width: 0, height: 0)

                // Zoom indicator
                ZoomIndicatorView(factor: viewModel.zoomFactor)
                    .padding(.bottom, 8)
            }

            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .accessibilityLabel("Error: \(error.localizedDescription)")
            }
        }
    }

    @ViewBuilder
    private var HUDCluster: some View {
        HStack {
            Spacer()
            HStack(spacing: 20) {
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
            }
            .padding(.trailing, 20)
            .padding(.top, 8)
        }
    }

    private var flashIcon: String {
        switch viewModel.flashMode {
        case .off: return "bolt.slash"
        case .on: return "bolt.fill"
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
                // The gesture's magnification is cumulative from gesture
                // start, so the base must stay fixed for the whole gesture;
                // `base × value` is the correct running zoom. Remember the
                // computed factor so `.onEnded` can seed the next gesture
                // from the value we actually applied, not the published
                // `zoomFactor` (which can lag behind the in-flight task).
                lastGestureFactor = factor
                Task { await viewModel.setZoom(factor) }
            }
            .onEnded { _ in
                zoomGestureBase = lastGestureFactor
            }
    }
}

private struct ThumbnailImage: View {
    let assetID: PhotoAssetID
    @State private var image: UIImage?
    let library: PikicamLibraryModel

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 58)
            }
        }
        .task {
            do {
                image = try await library.loadThumbnail(for: assetID)
            } catch {
                image = nil
            }
        }
    }
}

// MARK: - FramingOverlays

/// The framing aids drawn over the live preview: the 3×3 grid and the
/// aspect-ratio aperture mask.
///
/// One geometry source: the aperture rect is computed once here — the same
/// `PrintCrop` math the develop pipeline applies to the DNG at 1× zoom — and
/// handed to both overlays, so the grid is clipped exactly where the mask
/// dims the bands outside the selected aspect ratio (the iOS Camera
/// convention: grid lines never appear in the masked bands).
private struct FramingOverlays: View {
    let showsGrid: Bool
    let aspectRatio: AspectRatio

    var body: some View {
        GeometryReader { proxy in
            let bounds = CGRect(origin: .zero, size: proxy.size)
            let aperture = PrintCrop.rect(in: bounds, zoomFactor: 1.0, aspect: aspectRatio)
            ZStack {
                GridOverlayView(
                    showsGrid: showsGrid,
                    apertureRect: aspectRatio == .ratio4x3 ? nil : aperture
                )
                ApertureMaskOverlay(aspectRatio: aspectRatio, apertureRect: aperture)
            }
        }
    }
}

// MARK: - ApertureMaskOverlay

/// Compositional aperture mask: dims the bands outside the selected aspect
/// ratio over the full-sensor preview, matching the iOS Camera convention
/// (the wider FOV is preserved by cropping the shorter axis).
private struct ApertureMaskOverlay: View {
    let aspectRatio: AspectRatio
    /// The aperture rect in this view's coordinate space, precomputed by
    /// `FramingOverlays` so the grid and the mask share one geometry.
    let apertureRect: CGRect

    var body: some View {
        GeometryReader { proxy in
            if aspectRatio != .ratio4x3 {
                let size = proxy.size
                ZStack {
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.black.opacity(0.55)).frame(height: apertureRect.minY)
                        Rectangle().fill(.clear).frame(height: apertureRect.height)
                        Rectangle().fill(Color.black.opacity(0.55)).frame(height: size.height - apertureRect.maxY)
                    }
                    Rectangle()
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                        .frame(width: apertureRect.width, height: apertureRect.height)
                }
                .accessibilityIdentifier("aspect-overlay")
            } else {
                Color.clear
            }
        }
    }
}

// MARK: - ExposureSliderView

/// Vertical EV slider shown over the preview after a tap-to-meter. Dragging
/// moves a continuous −3…+3 stops value (top = brighter); the value is
/// snapped to 1/3 stops and committed to the view model when the drag ends.
private struct ExposureSliderView: View {
    @Binding var stops: Double
    var onCommit: () -> Void = {}

    private static let range: ClosedRange<Double> =
        Double(ExposureCompensation.minThird) * ExposureCompensation.step
        ... Double(ExposureCompensation.maxThird) * ExposureCompensation.step

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 5)
                    .frame(maxHeight: .infinity)
                ForEach([-3, -2, -1, 0, 1, 2, 3], id: \.self) { stop in
                    Circle()
                        .fill(Color.white.opacity(0.75))
                        .frame(width: stop == 0 ? 7 : 4, height: stop == 0 ? 7 : 4)
                        .position(x: proxy.size.width / 2, y: Self.y(for: Double(stop), in: height))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        stops = Self.stops(forY: value.location.y, in: height)
                    }
                    .onEnded { _ in onCommit() }
            )
        }
        .frame(width: 40)
        .overlay(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
                .padding(6)
                .background(.black.opacity(0.55))
                .clipShape(Capsule())
                .offset(y: -30)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("exposure-slider")
        .accessibilityLabel("Exposure compensation")
        .accessibilityValue(label)
    }

    private var label: String {
        ExposureCompensation(stops: stops).label
    }

    /// Maps EV stops to a y position: +3 (brightest) at the top of the track.
    private static func y(for stopValue: Double, in height: CGFloat) -> CGFloat {
        let fraction = (stopValue - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(1 - fraction) * height
    }

    /// Inverse of `y(for:)`: converts a drag location into continuous stops.
    private static func stops(forY y: CGFloat, in height: CGFloat) -> Double {
        guard height > 0 else { return 0 }
        let fraction = 1 - Double(y / height)
        return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
    }
}

// MARK: - SelfTimerCountdownView

/// Big centered number shown while the self-timer counts down. Doubles as
/// the cancel target — tapping anywhere on the screen cancels via the VM.
private struct SelfTimerCountdownView: View {
    let remaining: Int
    let onCancel: () -> Void

    var body: some View {
        Text("\(remaining)")
            .font(.system(size: 96, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(24)
            .background(.black.opacity(0.6))
            .clipShape(Circle())
            .contentShape(Rectangle())
            .onTapGesture(perform: onCancel)
            .accessibilityIdentifier("self-timer-countdown")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Cancels the timer")
    }
}
