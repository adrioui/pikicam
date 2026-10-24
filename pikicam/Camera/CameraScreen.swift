import SwiftUI

struct CameraScreen: View {
    @State private var engine = CameraEngine()
    @State private var isArchivePresented = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            statusRow
            ZStack {
                Skin.Ink.black
                CameraPreviewView(session: engine.session)
                    .accessibilityLabel("Viewfinder")
                if !engine.isRunning {
                    Text("STARTING CAMERA…")
                        .skin(.body)
                }
            }
            controls
        }
        .background(Skin.Ink.black.ignoresSafeArea())
        .task { await engine.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await engine.start() }
            } else if phase == .background {
                Task { await engine.handleAppBackground() }
            }
        }
        .sheet(isPresented: $isArchivePresented) {
            ArchiveScreen()
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Text("PIKICAM")
                .skin(.caption)
            Spacer()
            if engine.isRecording {
                recordReadout
            } else {
                Text("\(engine.savedCount) SAVED")
                    .skin(.caption, Skin.Ink.rule)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Skin.Ink.black)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Skin.Ink.rule).frame(height: Skin.hairline)
        }
    }

    private var recordReadout: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text("REC \(elapsed(context.date))")
                .skin(.title, Skin.Ink.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Skin.Ink.white)
        }
    }

    private func elapsed(_ now: Date) -> String {
        guard let started = engine.recordingStarted else { return "0:00" }
        let seconds = max(0, Int(now.timeIntervalSince(started)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            modeStrip
            if engine.mode == .photo {
                monoToggle
            }
            messages
            HStack {
                archiveButton
                Spacer()
                shutterButton
                Spacer()
                flipButton
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 16)
        .background(Skin.Ink.black)
        .overlay(alignment: .top) {
            Rectangle().fill(Skin.Ink.rule).frame(height: Skin.hairline)
        }
    }

    private var modeStrip: some View {
        HStack(spacing: 8) {
            ForEach(CameraEngine.Mode.allCases, id: \.rawValue) { mode in
                SkinChip(
                    title: mode.rawValue,
                    size: .caption,
                    selected: engine.mode == mode
                ) {
                    engine.mode = mode
                }
                .accessibilityIdentifier("camera.mode.\(mode.rawValue)")
            }
        }
    }

    private var monoToggle: some View {
        SkinChip(
            title: engine.isMonoOn ? "BNW ON" : "BNW OFF",
            size: .caption,
            selected: engine.isMonoOn
        ) {
            engine.isMonoOn.toggle()
        }
        .accessibilityLabel("Black and white toggle")
        .accessibilityValue(engine.isMonoOn ? "On" : "Off")
        .accessibilityIdentifier("camera.bnw")
    }

    @ViewBuilder
    private var messages: some View {
        if engine.photosDenied {
            VStack(spacing: 8) {
                Text("PHOTOS ACCESS IS OFF — CAPTURES CAN'T BE SAVED.")
                    .skin(.caption)
                SkinChip(title: "OPEN SETTINGS", size: .caption, selected: true) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        } else if engine.mode == .video, let clip = engine.clipMessage {
            Text(clip).skin(.caption)
        } else if let message = engine.lastMessage {
            Text(message).skin(.caption)
        }
    }

    private var archiveButton: some View {
        Button {
            isArchivePresented = true
        } label: {
            Image(systemName: "photo.on.rectangle")
                .skin(.title)
                .frame(width: 64, height: 64)
        }
        .accessibilityLabel("Open archive")
    }

    private var flipButton: some View {
        Button {
            Task { await engine.flipCamera() }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .skin(.title)
                .frame(width: 64, height: 64)
        }
        .accessibilityLabel("Flip camera")
        .accessibilityIdentifier("camera.flip")
    }

    private var shutterButton: some View {
        Button {
            Task {
                if engine.mode == .video {
                    if engine.isRecording {
                        await engine.stopRecording()
                    } else {
                        await engine.startRecording()
                    }
                    return
                }
                WalkMark.mark("shutter-pressed")
                if let capture = await engine.capturePhoto() {
                    WalkMark.mark("capture-returned")
                    await engine.saveToPhotos(capture)
                }
            }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Skin.Ink.white, lineWidth: 3)
                    .frame(width: 72, height: 72)
                if engine.mode == .video && engine.isRecording {
                    Rectangle()
                        .fill(Skin.Ink.white)
                        .frame(width: 26, height: 26)
                } else if engine.mode == .video {
                    Circle()
                        .strokeBorder(Skin.Ink.white, lineWidth: Skin.hairline)
                        .frame(width: 58, height: 58)
                } else {
                    Circle()
                        .fill(engine.isCapturing ? Skin.Ink.rule : Skin.Ink.white)
                        .frame(width: 58, height: 58)
                }
            }
        }
        .disabled(engine.isCapturing)
        .accessibilityLabel(shutterLabel)
        .accessibilityIdentifier("camera.shutter")
    }

    private var shutterLabel: String {
        engine.mode == .video ? (engine.isRecording ? "Stop recording" : "Record") : "Shutter"
    }
}
