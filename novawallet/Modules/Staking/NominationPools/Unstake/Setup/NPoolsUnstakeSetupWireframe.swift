import Foundation

final class NPoolsUnstakeSetupWireframe: NPoolsUnstakeSetupWireframeProtocol {
    let state: NPoolsStakingSharedStateProtocol

    init(state: NPoolsStakingSharedStateProtocol) {
        self.state = state
    }

    func showConfirm(from view: NPoolsUnstakeSetupViewProtocol?, amount: Decimal) {
        guard
            let confirmView = NPoolsUnstakeConfirmViewFactory.createView(for: amount, state: state) else {
            return
        }

        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }
}
