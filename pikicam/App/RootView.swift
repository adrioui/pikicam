import SwiftUI

struct RootView: View {
    let dependencies: Dependencies
    @State private var permissionsSatisfied: Bool

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        let isFake = ProcessInfo.processInfo.arguments.contains("-pikicam.fake")
        _permissionsSatisfied = State(initialValue: isFake)
    }

    var body: some View {
        if permissionsSatisfied {
            CameraScreen(deps: dependencies)
        } else {
            PermissionsScreen(deps: dependencies) {
                permissionsSatisfied = true
            }
        }
    }
}
