import SwiftUI

struct RootView: View {
    @State private var frameTimeProbe: FrameTimeProbe?

    var body: some View {
        CameraScreen()
            .task { WalkMark.reset() }
            .onAppear { WalkMark.mark("root-appeared") }
            .task {
                if ProcessInfo.processInfo.arguments.contains("-pikicam.frametime") {
                    let probe = FrameTimeProbe()
                    frameTimeProbe = probe
                    await probe.run(duration: 65)
                }
            }
    }
}
