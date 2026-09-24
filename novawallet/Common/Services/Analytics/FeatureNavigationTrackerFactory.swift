import Foundation

enum FeatureNavigationTrackerFactory {
    static func createDefault() -> FeatureNavigationTracking {
        sharedTracker
    }

    private static let sharedTracker = FeatureNavigationTracker(
        analytics: AnalyticsFacadeFactory.createDefault()
    )
}
