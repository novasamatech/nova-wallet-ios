final class StartStakingInfoRelaychainWireframe: StartStakingInfoWireframe,
    StartStakingInfoRelaychainWireframeProtocol {
    func showSetupAmount(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        state: StakingSharedState
    ) {
        guard let setupAmountView = StakingSetupAmountViewFactory.createView(
            chainAsset: chainAsset,
            state: state
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(setupAmountView.controller, animated: true)
    }
}
