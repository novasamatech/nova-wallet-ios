import Foundation

final class MythosStkUnstakeSetupWireframe: MythosStkUnstakeSetupWireframeProtocol {
    let state: MythosStakingSharedStateProtocol

    init(state: MythosStakingSharedStateProtocol) {
        self.state = state
    }

    func showConfirm(
        from view: CollatorStkFullUnstakeSetupViewProtocol?,
        collator: DisplayAddress
    ) {
        guard let confirmView = MythosStkUnstakeConfirmViewFactory.createView(
            for: state,
            selectedCollator: collator
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}
