import Foundation

final class MythosStakingSetupWireframe: MythosStakingSetupWireframeProtocol {
    let state: MythosStakingSharedStateProtocol

    init(state: MythosStakingSharedStateProtocol) {
        self.state = state
    }

    func showConfirmation(
        from _: CollatorStakingSetupViewProtocol?,
        model _: MythosStakeModel,
        initialDelegator _: MythosStakingDetails?
    ) {
        // TODO: Implement in separate task
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
