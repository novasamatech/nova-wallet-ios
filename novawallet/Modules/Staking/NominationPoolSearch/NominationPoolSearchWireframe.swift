import Foundation

final class NominationPoolSearchWireframe: NominationPoolSearchWireframeProtocol {
    func complete(from view: ControllerBackedProtocol?) {
        if let setupAmountView: StakingSetupAmountViewProtocol = view?.controller.navigationController?.findTopView() {
            view?.controller.navigationController?.popToViewController(
                setupAmountView.controller,
                animated: true
            )
        }
    }
}
