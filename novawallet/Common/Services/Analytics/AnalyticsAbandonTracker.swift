import Foundation
import NovaAnalytics

final class AnalyticsAbandonTracker {
    var makeEvent: () -> AnalyticsEvent?

    private var isProceeded: Bool = false

    init(makeEvent: @escaping () -> AnalyticsEvent?) {
        self.makeEvent = makeEvent
    }

    deinit {
        guard !isProceeded, let event = makeEvent() else {
            return
        }

        AnalyticsFacadeFactory.createDefault().track(event)
    }

    func markProceeded() {
        isProceeded = true
    }
}
