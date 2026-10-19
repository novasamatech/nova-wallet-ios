import Foundation

enum SubtensorConfirmTapRule {
    static func verifiedPlan(
        for unstakeModel: SubtensorUnstakeModel,
        in state: Multistaking.SubtensorState?
    ) -> SubtensorUnstakePlan? {
        guard let state else {
            return nil
        }

        guard
            let group = SubtensorPortfolioBuilder.build(state: state).group(netuid: unstakeModel.netuid),
            !group.positions.contains(where: { $0.stakeAlpha == 0 }),
            Set(group.positions.map(\.hotkey)) == Set(unstakeModel.groupHotkeys.keys) else {
            return nil
        }

        guard let rebuilt = unstakeModel.plan.rebuilt(from: group) else {
            return nil
        }

        let drifted = SubtensorFlowConstants.exceedsFullExitDrift(
            live: rebuilt.amount,
            reviewed: unstakeModel.amount
        )

        return drifted ? nil : rebuilt
    }
}
