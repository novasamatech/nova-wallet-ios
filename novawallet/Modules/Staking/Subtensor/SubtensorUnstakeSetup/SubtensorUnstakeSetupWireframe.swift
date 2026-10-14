import Foundation

final class SubtensorUnstakeSetupWireframe: SubtensorUnstakeSetupWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func showConfirm(
        from view: SubtensorUnstakeSetupViewProtocol?,
        model: SubtensorConfirmModel
    ) {
        guard let confirmView = SubtensorConfirmViewFactory.createView(
            for: state,
            model: model
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }
}
