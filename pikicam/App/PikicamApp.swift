import SwiftUI

/// pikicam: A zero-process iPhone camera app.
///
/// Captures a single Bayer RAW exposure and develops it with every
/// computational-photography knob turned off, producing authentic,
/// film-like images.
@main
struct PikicamApp: App {
    @State private var cameraViewModel: CameraViewModel
    @State private var libraryModel: PikicamLibraryModel

    init() {
        let library = PikicamLibraryModel()
        _libraryModel = State(initialValue: library)
        _cameraViewModel = State(initialValue: CameraViewModel(libraryModel: library))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(cameraViewModel)
                .environment(libraryModel)
                .preferredColorScheme(.dark)
        }
    }
}
