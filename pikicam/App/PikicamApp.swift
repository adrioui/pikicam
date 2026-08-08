import SwiftUI

/// pikicam: A zero-process iPhone camera app.
///
/// Captures a single Bayer RAW exposure and develops it with every
/// computational-photography knob turned off, producing authentic,
/// film-like images.
@main
struct PikicamApp: App {
    @State private var cameraViewModel = CameraViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(cameraViewModel)
                .preferredColorScheme(.dark)
        }
    }
}
