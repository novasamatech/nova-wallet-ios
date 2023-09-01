import Foundation

final class NominationPoolBondMoreSetupWireframe: NominationPoolBondMoreBaseWireframe {
    let state: NPoolsStakingSharedStateProtocol

    init(state: NPoolsStakingSharedStateProtocol) {
        self.state = state
    }
}

extension NominationPoolBondMoreSetupWireframe: NominationPoolBondMoreSetupWireframeProtocol {
    func showConfirm(from view: ControllerBackedProtocol?, amount: Decimal) {
        guard let confirmView = NominationPoolBondMoreConfirmViewFactory.createView(state: state, amount: amount) else {
            return
        }
        view?.controller.navigationController?.pushViewController(confirmView.controller, animated: true)
    }
}
