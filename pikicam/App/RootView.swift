import SwiftUI

struct RootView: View {
    var body: some View {
        CameraScreen()
            .task { WalkMark.reset() }
            .onAppear { WalkMark.mark("root-appeared") }
    }
}
