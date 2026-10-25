import SwiftUI

@main
struct PikicamApp: App {
    init() {
        Skin.applyGlobalChrome()
        MetricWitness.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

}
