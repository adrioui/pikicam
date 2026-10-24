import SwiftUI

struct RootView: View {
    @State private var frameTimeProbe: FrameTimeProbe?
    @State private var panelMode = false

    private var isParity: Bool {
        ProcessInfo.processInfo.arguments.contains("-pikicam.parity")
    }

    var body: some View {
        Group {
            if panelMode {
                PanelRamp()
            } else if isParity {
                Text("PARITY RUN IN PROGRESS")
                    .skin(.body)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Skin.Ink.black.ignoresSafeArea())
            } else {
                CameraScreen()
            }
        }
        .task { WalkMark.reset() }
            .onAppear { WalkMark.mark("root-appeared") }
            .task {
                if ProcessInfo.processInfo.arguments.contains("-pikicam.frametime") {
                    let probe = FrameTimeProbe()
                    frameTimeProbe = probe
                    await probe.run(duration: 65)
                }
                if ProcessInfo.processInfo.arguments.contains("-pikicam.parity") {
                    await ParityCapture.run()
                }
                panelMode = ProcessInfo.processInfo.arguments.contains("-pikicam.panel")
            }
    }
}
