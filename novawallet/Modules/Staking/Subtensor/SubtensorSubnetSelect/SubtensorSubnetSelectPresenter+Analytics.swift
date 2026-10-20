import Foundation
import NovaAnalytics

extension SubtensorSubnetSelectPresenter: AnalyticsTracking {
    func trackRootSelected() {
        abandonTracker?.markProceeded()

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

    func trackListOpened() {
        trackAnalytics(
            .subnetListOpened(
                source: source,
                sort: browseState.sort.analyticsKey,
                hideThinPools: browseState.filters.hideThinPools
            )
        )
    }

    func trackSearchIfNeeded(_ query: String) {
        guard !isSearchTracked, !query.isEmpty else {
            return
        }

        isSearchTracked = true
        trackInteraction(.search)
    }

    func trackInteraction(_ interaction: SubnetListInteraction) {
        trackAnalytics(.subnetListInteracted(interaction))
    }
}

extension SubtensorSubnetSort {
    var analyticsKey: SubnetSortKey {
        switch self {
        case .poolDepth: .poolSize
        case .age: .age
        case .apy: .apy
        case .sevenDayChange: .sevenDayChange
        case .name: .name
        }
    }
}
