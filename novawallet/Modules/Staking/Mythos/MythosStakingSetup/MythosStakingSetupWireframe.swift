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
        delegate: ParaStkSelectCollatorsDelegate
    ) {
        guard let selectView = ParaStkSelectCollatorsViewFactory.createMythosStakingView(
            with: state,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(selectView.controller, animated: true)
    }
}
