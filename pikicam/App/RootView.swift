import SwiftUI

struct RootView: View {
    let dependencies: Dependencies
    @State private var permissionsSatisfied: Bool

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        let isFake = ProcessInfo.processInfo.arguments.contains("-pikicam.fake")
            || ProcessInfo.processInfo.arguments.contains("-pikicam.selfwalk")
        _permissionsSatisfied = State(initialValue: isFake)
    }

    var body: some View {
        Group {
        if permissionsSatisfied {
            CameraScreen(deps: dependencies)
        } else {
            PermissionsScreen(deps: dependencies) {
                WalkMark.mark("enter-tapped")
                permissionsSatisfied = true
            }
        }
        }
        .task { WalkMark.reset() }
        .onAppear { WalkMark.mark("root-appeared") }
    }
}
