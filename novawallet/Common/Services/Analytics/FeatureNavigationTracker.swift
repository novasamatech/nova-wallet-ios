import Foundation
import NovaAnalytics

protocol FeatureNavigationTracking: AnyObject {
    func trackTabSwitched(to tab: AnalyticsTab)
    func trackFeatureOpened(_ feature: FeatureId)
    func trackNovaCardOpened()
}

final class FeatureNavigationTracker {
    private let analytics: AnalyticsTrackingProtocol
    private let mutex = NSLock()

    private var currentTab: AnalyticsTab?
    private var currentFeature: FeatureId?

    init(analytics: AnalyticsTrackingProtocol) {
        self.analytics = analytics
    }
}

// MARK: - FeatureNavigationTracking

extension FeatureNavigationTracker: FeatureNavigationTracking {
    func trackTabSwitched(to tab: AnalyticsTab) {
        mutex.lock()

        let hadPreviousTab = currentTab != nil
        let didChange = currentTab != tab
        currentTab = tab

        mutex.unlock()

        guard hadPreviousTab, didChange else {
            return
        }

        analytics.track(.tabSwitched(tab: tab))
    }

    func trackFeatureOpened(_ feature: FeatureId) {
        mutex.lock()

        let didChange = currentFeature != feature
        currentFeature = feature

        mutex.unlock()

        guard didChange else {
            return
        }

        analytics.track(.featureOpened(feature))
    }

    func trackNovaCardOpened() {
        analytics.track(.novaCardOpened())
    }
}
