import SwiftUI

struct CameraScreen: View {
    @State private var engine = CameraEngine()
    @State private var isArchivePresented = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            statusRow
            ZStack {
                Color.black
                CameraPreviewView(session: engine.session)
                    .accessibilityLabel("Viewfinder")
                if !engine.isRunning {
                    Text("STARTING CAMERA…")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            controls
        }
        .background(Color.black.ignoresSafeArea())
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
        HStack {
            modeStrip
            Spacer()
            if engine.isRecording {
                recordTimer
            } else {
                Text("\(engine.savedCount) SAVED")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color.black)
    }

    private var modeStrip: some View {
        HStack(spacing: 8) {
            ForEach(CameraEngine.Mode.allCases, id: \.rawValue) { mode in
                let selected = engine.mode == mode
                Button {
                    engine.mode = mode
                } label: {
                    Text(mode.rawValue.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(selected ? .black : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(selected ? Color.white : Color.clear)
                }
                .accessibilityIdentifier("camera.mode.\(mode.rawValue)")
            }
        }
    }

    private var recordTimer: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(elapsed(context.date))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.red)
        }
    }

    private func elapsed(_ now: Date) -> String {
        guard let started = engine.recordingStarted else { return "0:00" }
        let seconds = max(0, Int(now.timeIntervalSince(started)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var statusRowLegacy: some View {
        HStack {
            Text("[ PIKICAM ]")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Text("\(engine.savedCount) SAVED")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color.black)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if engine.mode == .photo {
                monoToggle
            }
            if let clip = engine.clipMessage, engine.mode == .video {
                Text(clip)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            if engine.photosDenied {
                denialBanner
            } else if let message = engine.lastMessage {
                Text(message)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
            }
            HStack {
                archiveButton
                Spacer()
                shutterButton
                Spacer()
                Color.clear.frame(width: 64, height: 64)
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 16)
        .background(Color.black)
    }

    private var monoToggle: some View {
        Button {
            engine.isMonoOn.toggle()
        } label: {
            Text(engine.isMonoOn ? "[ BNW ON ]" : "[ BNW OFF ]")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(engine.isMonoOn ? Color.white.opacity(0.25) : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.white, lineWidth: 1))
        }
        .accessibilityLabel("Black and white toggle")
        .accessibilityValue(engine.isMonoOn ? "On" : "Off")
        .accessibilityIdentifier("camera.bnw")
    }

    private var denialBanner: some View {
        VStack(spacing: 8) {
            Text("Photos access is off — captures can't be saved.")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
            Button("OPEN SETTINGS") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
        }
    }

    private var archiveButton: some View {
        Button {
            isArchivePresented = true
        } label: {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
        }
        .accessibilityLabel("Open archive")
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
                    .strokeBorder(engine.mode == .video ? Color.red : Color.white, lineWidth: 3)
                    .frame(width: 72, height: 72)
                if engine.mode == .video && engine.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red)
                        .frame(width: 26, height: 26)
                } else {
                    Circle()
                        .fill(fillColor)
                        .frame(width: 58, height: 58)
                }
            }
        }
        .disabled(engine.isCapturing)
        .accessibilityLabel(accessoryLabel)
        .accessibilityIdentifier("camera.shutter")
    }

    private var fillColor: Color {
        if engine.mode == .video {
            return .red
        }
        return engine.isCapturing ? Color.white.opacity(0.5) : Color.white
    }

    private var accessoryLabel: String {
        engine.mode == .video ? (engine.isRecording ? "Stop recording" : "Record") : "Shutter"
    }
}
