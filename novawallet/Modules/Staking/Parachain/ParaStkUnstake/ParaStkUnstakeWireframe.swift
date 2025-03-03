import Foundation

final class ParaStkUnstakeWireframe: ParaStkUnstakeWireframeProtocol {
    let state: ParachainStakingSharedStateProtocol

    init(state: ParachainStakingSharedStateProtocol) {
        self.state = state
    }

    func showUnstakingConfirm(
        from view: CollatorStkPartialUnstakeSetupViewProtocol?,
        collator: DisplayAddress,
        callWrapper: UnstakeCallWrapper
    ) {
        guard let confirmView = ParaStkUnstakeConfirmViewFactory.createView(
            for: state,
            callWrapper: callWrapper,
            collator: collator
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }
}
