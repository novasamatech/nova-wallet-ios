import Foundation

enum SubtensorConfirmQuoteVerdict: Equatable {
    case proceed(latest: SubtensorTradeQuote, limitPrice: Balance)
    case quoteMissing
    case priceMoved
}

enum SubtensorConfirmTapRule {
    static func quoteVerdict(
        latest: SubtensorTradeQuote?,
        acknowledged: SubtensorTradeQuote?,
        now: Date = Date()
    ) -> SubtensorConfirmQuoteVerdict {
        guard
            let latest,
            let acknowledged,
            now.timeIntervalSince(latest.quote.capturedAt) <= SubtensorStakingFlowConstants.quoteStalenessWindow else {
            return .quoteMissing
        }

        let limitPrice = latest.tighterLimit(than: acknowledged.limitPrice)

        guard latest.isFillable(atLimit: limitPrice) else {
            return .priceMoved
        }

        return .proceed(latest: latest, limitPrice: limitPrice)
    }

    static func verifiedExitHotkeys(
        for unstakeModel: SubtensorUnstakeModel,
        in state: Multistaking.SubtensorStakingState?
    ) -> [AccountId]? {
        guard let expected = unstakeModel.exitHotkeys, let state else {
            return nil
        }

        guard
            let group = SubtensorPortfolioBuilder.build(state: state).group(netuid: unstakeModel.netuid),
            !group.positions.contains(where: { $0.stakeAlpha == 0 }) else {
            return nil
        }

        let basis = SubtensorGroupUnstakeBasis.make(from: group)

        guard
            !SubtensorStakingFlowConstants.exceedsFullExitDrift(live: basis.total, reviewed: unstakeModel.amount),
            let rebuilt = basis.exitHotkeys(for: basis.total), rebuilt == expected else {
            return nil
        }

        return rebuilt
    }
}
