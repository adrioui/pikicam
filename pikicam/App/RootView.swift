import SwiftUI

struct RootView: View {
    let dependencies: Dependencies

    var body: some View {
        CameraScreen(deps: dependencies)
    }
}
