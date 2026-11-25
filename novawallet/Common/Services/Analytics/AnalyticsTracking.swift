import Foundation
import NovaAnalytics

protocol AnalyticsTracking {
    /// Declared as a requirement so that a type can take the tracker through its init
    /// and a test can observe what it emits; the default is the shared facade.
    var analyticsTracker: AnalyticsTrackingProtocol { get }
}

extension AnalyticsTracking {
    var analyticsTracker: AnalyticsTrackingProtocol {
        AnalyticsFacadeFactory.createDefault()
    }

    func trackAnalytics(_ event: AnalyticsEvent?) {
        guard let event else {
            return
        }

        analyticsTracker.track(event)
    }

    func trackFeatureOpened(_ feature: FeatureId) {
        FeatureNavigationTrackerFactory.createDefault().trackFeatureOpened(feature)
    }

    func trackTabSwitched(to tab: AnalyticsTab) {
        FeatureNavigationTrackerFactory.createDefault().trackTabSwitched(to: tab)
    }

    func trackNovaCardOpened() {
        FeatureNavigationTrackerFactory.createDefault().trackNovaCardOpened()
    }
}
