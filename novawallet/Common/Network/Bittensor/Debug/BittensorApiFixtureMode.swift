import Foundation

#if DEBUG
    enum BittensorApiFixtureMode {
        static let launchArgument = "-BittensorApiFixtures"

        static var isEnabled: Bool {
            ProcessInfo.processInfo.arguments.contains(launchArgument)
        }
    }
#endif
