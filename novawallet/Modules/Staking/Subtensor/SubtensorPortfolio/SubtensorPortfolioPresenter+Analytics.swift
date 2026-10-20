import Foundation
import NovaAnalytics

extension SubtensorPortfolioPresenter: AnalyticsTracking {
    func trackAddPositionOpened() {
        let event = chainAsset.chain.analyticsNetworkName.map { network in
            AnalyticsEvent.stakingFlowOpened(network: network, source: .portfolioAddPosition)
        }

        trackAnalytics(event)
    }
}
