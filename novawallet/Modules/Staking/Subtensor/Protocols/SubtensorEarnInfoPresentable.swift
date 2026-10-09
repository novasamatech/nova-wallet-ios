import Foundation

protocol SubtensorEarnInfoPresentable {}

extension SubtensorEarnInfoPresentable {
    func presentSubtensorEarnInfo(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        flowState: SubtensorStakingFlowStateProtocol
    ) {
        guard
            let view,
            let earnInfoView = StartStakingInfoViewFactory.createSubtensorView(
                for: Multistaking.ChainAssetOption(chainAsset: chainAsset, type: .subtensor),
                flowState: flowState
            ) else {
            return
        }

        let navigationController = ImportantFlowViewFactory.createNavigation(from: earnInfoView.controller)

        view.controller.presentWithCardLayout(navigationController, animated: true)
    }
}
