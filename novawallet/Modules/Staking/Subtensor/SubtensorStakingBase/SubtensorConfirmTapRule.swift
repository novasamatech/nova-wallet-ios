import Foundation

enum SubtensorConfirmTapRule {
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
