import Foundation
import NovaAnalytics

protocol AnalyticsTracking {}

extension AnalyticsTracking {
    func trackAnalytics(_ event: AnalyticsEvent?) {
        guard let event else {
            return
        }

        AnalyticsFacadeFactory.createDefault().track(event)
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
