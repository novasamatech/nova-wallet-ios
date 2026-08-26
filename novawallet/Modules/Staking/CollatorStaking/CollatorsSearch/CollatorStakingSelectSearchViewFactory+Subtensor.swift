import Foundation
import Foundation_iOS

extension CollatorStakingSelectSearchViewFactory {
    static func createSubtensorStakingView(
        for state: SubtensorStakingSharedStateProtocol,
        delegates: [CollatorStakingSelectionInfoProtocol],
        delegate: CollatorStakingSelectDelegate
    ) -> CollatorStakingSelectSearchViewProtocol? {
        createView(
            for: SubtensorSelectSearchWireframe(sharedState: state),
            chainAsset: state.stakingOption.chainAsset,
            collators: delegates,
            delegate: delegate,
            displaysRewards: false
        )
    }
}
