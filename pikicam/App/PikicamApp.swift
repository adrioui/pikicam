import SwiftUI

@main
struct PikicamApp: App {
    init() {
        Skin.applyGlobalChrome()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }

}
