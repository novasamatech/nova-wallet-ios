import Foundation

final class NominationPoolSearchWireframe: NominationPoolSearchWireframeProtocol {
    func complete(from view: ControllerBackedProtocol?) {
        if let amountView: StakingSetupAmountViewProtocol = view?.controller.navigationController?.findTopView() {
            view?.controller.navigationController?.popToViewController(
                amountView.controller,
                animated: true
            )
        }
    }
}
