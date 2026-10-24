import SwiftUI

@main
struct PikicamApp: App {
    @State private var dependencies: Dependencies

    init() {
        if Self.isSelfWalk() {
            self.dependencies = .live()
        } else {
            self.dependencies = .fake(scenario: Self.launchScenario())
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
    }

    private static func isSelfWalk() -> Bool {
        ProcessInfo.processInfo.arguments.contains("-pikicam.selfwalk")
    }

    private static func launchScenario() -> FakeScenario {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-pikicam.fake"),
            index + 1 < arguments.count,
            let scenario = FakeScenario(rawValue: arguments[index + 1])
        else {
            return .standard
        }
        return scenario
    }
}
