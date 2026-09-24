import Foundation
import NovaAnalytics

extension AnalyticsTracking {
    func trackDAppOpened(
        url: URL,
        source: DAppOpenSource,
        isKnown: Bool
    ) {
        let event = AnalyticsContentValue.dappHost(url).map { host in
            AnalyticsEvent.dappOpened(
                host: host,
                source: source,
                isKnown: isKnown
            )
        }

        trackAnalytics(event)
    }
}
