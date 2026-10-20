import Foundation
import NovaAnalytics

extension SubtensorSubnetDetailsPresenter: AnalyticsTracking {
    func trackSubnetSelected() {
        abandonTracker.markProceeded()

        let event = chainAsset.subtensorAnalyticsSubject(for: input.target).map { subject in
            AnalyticsEvent.subtensorTypeSelected(
                subject: subject,
                method: host == .picker ? .pickerSubnet : .subnetDetails,
                netuid: input.target.analyticsNetuid
            )
        }

        trackAnalytics(event)
    }
}
