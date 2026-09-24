import Foundation
import NovaAnalytics

extension BaseReferendumVoteConfirmPresenter: AnalyticsTracking {
    func makeVoteCastEvent(for vote: ReferendumNewVote) -> AnalyticsEvent? {
        guard
            let network = chain.analyticsNetworkName,
            let precision = chain.utilityAsset()?.displayInfo.assetPrecision,
            let amount = Decimal.fromSubstrateAmount(
                vote.voteAction.amount(),
                precision: precision
            ) else {
            return nil
        }

        return .governanceVoteCast(
            direction: vote.voteAction.analyticsDirection,
            network: network,
            amount: amount,
            rate: priceData?.analyticsRate,
            conviction: vote.voteAction.analyticsConviction
        )
    }

    func trackVoteCast(_ vote: ReferendumNewVote) {
        trackAnalytics(makeVoteCastEvent(for: vote))
    }
}
