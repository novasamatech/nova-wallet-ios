import Foundation

final class SubtensorUnstakeSetupWireframe: SubtensorUnstakeSetupWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func showConfirm(
        from view: CollatorStkPartialUnstakeSetupViewProtocol?,
        model: SubtensorUnstakeConfirmModel
    ) {
        guard let confirmView = SubtensorUnstakeConfirmViewFactory.createView(
            for: state,
            model: model
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }

    func showSlippageEdit(
        from view: CollatorStkPartialUnstakeSetupViewProtocol?,
        current: BigRational,
        completion: @escaping (BigRational) -> Void
    ) {
        guard let slippageView = SwapSlippageViewFactory.createSubtensorView(
            percent: current,
            chainAsset: state.stakingOption.chainAsset,
            completionHandler: completion
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            slippageView.controller,
            animated: true
        )
    }
}
