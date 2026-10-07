import Foundation

enum SubtensorConfirmQuoteVerdict: Equatable {
    case proceed(latest: SubtensorTradeQuote, acknowledged: SubtensorTradeQuote)
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

        guard latest.isFillable(atLimit: acknowledged.limitPrice) else {
            return .priceMoved
        }

        return .proceed(latest: latest, acknowledged: acknowledged)
    }

    static func verifiedExitHotkeys(
        for unstakeModel: SubtensorUnstakeModel,
        in state: Multistaking.SubtensorStakingState?
    ) -> [AccountId]? {
        guard let expected = unstakeModel.exitHotkeys, let state else {
            return nil
        }

        guard
            let group = liveGroup(for: unstakeModel.netuid, in: state),
            !group.positions.contains(where: { $0.stakeAlpha == 0 }) else {
            return nil
        }

        let basis = SubtensorGroupUnstakeBasis.make(from: group)

        guard let rebuilt = basis.exitHotkeys(for: basis.total), rebuilt == expected else {
            return nil
        }

        return rebuilt
    }
}

private extension SubtensorConfirmTapRule {
    static func liveGroup(
        for netuid: UInt16,
        in state: Multistaking.SubtensorStakingState
    ) -> SubtensorPortfolioGroup? {
        let portfolio = SubtensorPortfolioBuilder.build(state: state)

        return ([portfolio.stakedRoot].compactMap { $0 } + portfolio.subnets).first { $0.netuid == netuid }
    }
}
