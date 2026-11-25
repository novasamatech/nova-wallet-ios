import Foundation
import NovaAnalytics

final class AnalyticsTrackerSpy: AnalyticsTrackingProtocol {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }

    func trackAndFlush(
        _ event: AnalyticsEvent,
        reason _: AnalyticsFlushReason,
        completion: @escaping () -> Void
    ) {
        events.append(event)
        completion()
    }
}
