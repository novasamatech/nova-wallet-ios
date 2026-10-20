import Foundation
import NovaAnalytics

extension SubtensorSubnetSelectPresenter: AnalyticsTracking {
    func trackRootSelected() {
        abandonTracker.markProceeded()

        let target = SubtensorStakeTarget.root

        let event = chainAsset.subtensorAnalyticsSubject(for: target).map { subject in
            AnalyticsEvent.subtensorTypeSelected(
                subject: subject,
                method: .pickerRootRow,
                netuid: target.analyticsNetuid
            )
        }

        trackAnalytics(event)
    }
}
