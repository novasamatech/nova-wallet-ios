import Foundation
import NovaAnalytics

extension SubtensorPortfolioPresenter: AnalyticsTracking {
    func trackAddPositionOpened() {
        let event = chainAsset.chain.analyticsNetworkName.map { network in
            AnalyticsEvent.stakingFlowOpened(network: network, source: .portfolioAddPosition)
        }

        trackAnalytics(event)
    }

    func trackAddPositionRefusal(_ reason: StakingBlockedReason) {
        trackAnalytics(
            .subtensorStakingBlocked(
                flow: .stake,
                reason: reason,
                walletType: wallet.type.analyticsWalletType,
                target: nil
            )
        )
    }

    func trackOpenedIfResolved(_ viewModel: SubtensorPortfolioViewModel, groups: [SubtensorPortfolioGroup]?) {
        guard !isOpenedTracked, let groups else {
            return
        }

        let chartState: StakingChartState?

        switch viewModel.content {
        case let .positions(header, _, _):
            switch header.chart {
            case .loading:
                return
            case .chart:
                chartState = .shown
            case .unavailable, .hidden:
                chartState = .unavailable
            }
        case .empty:
            chartState = nil
        }

        isOpenedTracked = true

        trackAnalytics(
            .subtensorPortfolioOpened(
                source: analyticsSource,
                positions: CountBucket(count: groups.count),
                hasRoot: groups.contains { $0.netuid == SubtensorPallet.rootNetuid },
                chartState: chartState
            )
        )
    }
}
