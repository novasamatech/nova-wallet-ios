import Foundation

final class MythosStakingSetupWireframe: MythosStakingSetupWireframeProtocol {
    let state: MythosStakingSharedStateProtocol

    init(state: MythosStakingSharedStateProtocol) {
        self.state = state
    }

    func showConfirmation(
        from view: CollatorStakingSetupViewProtocol?,
        model: MythosStakingConfirmModel
    ) {
        guard let confirmView = MythosStakingConfirmViewFactory.createView(
            for: state,
            model: model
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }

    func showCollatorSelection(
        from view: CollatorStakingSetupViewProtocol?,
        delegate: CollatorStakingSelectDelegate
    ) {
        guard let selectView = CollatorStakingSelectViewFactory.createMythosStakingView(
            with: state,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(selectView.controller, animated: true)
    }
}
