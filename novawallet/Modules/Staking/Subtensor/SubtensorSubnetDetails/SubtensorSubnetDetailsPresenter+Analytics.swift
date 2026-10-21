import Foundation
import NovaAnalytics

extension SubtensorSubnetDetailsPresenter: AnalyticsTracking {
    func trackSubnetSelected() {
        abandonTracker?.markProceeded()

        let event = chainAsset.subtensorAnalyticsSubject(for: input.target).map { subject in
            AnalyticsEvent.subtensorTypeSelected(
                subject: subject,
                method: host == .picker ? .pickerSubnet : .subnetDetails,
                netuid: input.target.analyticsNetuid
            )
        }

        trackAnalytics(event)
    }

    func trackOpened(period: SubtensorPricePeriod?) {
        trackAnalytics(
            .subnetDetailsOpened(
                netuid: input.target.analyticsNetuid,
                source: host == .picker ? .picker : .setup,
                period: period?.analyticsPeriod
            )
        )
    }
}

extension SubtensorPricePeriod {
    var analyticsPeriod: AnalyticsPricePeriod {
        switch self {
        case .day: .day
        case .week: .week
        case .month: .month
        case .quarter: .quarter
        case .year: .year
        case .all: .all
        }
    }
}
