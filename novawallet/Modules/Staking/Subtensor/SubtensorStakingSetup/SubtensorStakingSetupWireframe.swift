import Foundation

final class SubtensorStakingSetupWireframe: SubtensorStakingSetupWireframeProtocol {
    let state: SubtensorStakingSharedStateProtocol

    init(state: SubtensorStakingSharedStateProtocol) {
        self.state = state
    }

    func showConfirmation(
        from view: CollatorStakingSetupViewProtocol?,
        model: SubtensorStakingConfirmModel
    ) {
        guard let confirmView = SubtensorStakingConfirmViewFactory.createView(
            for: state,
            model: model
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }

    func showDelegateSelection(
        from view: CollatorStakingSetupViewProtocol?,
        delegate: CollatorStakingSelectDelegate
    ) {
        guard let selectView = CollatorStakingSelectViewFactory.createSubtensorStakingView(
            with: state,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(selectView.controller, animated: true)
    }
}
