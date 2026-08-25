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
}
