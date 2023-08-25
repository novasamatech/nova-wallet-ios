import Foundation

final class NominationPoolSearchWireframe: NominationPoolSearchWireframeProtocol {
    func complete(from view: ControllerBackedProtocol?) {
        if let stakingSetupAmountView: StakingSetupAmountViewProtocol = view?.controller.navigationController?.findTopView() {
            view?.controller.navigationController?.popToViewController(
                stakingSetupAmountView.controller,
                animated: true
            )
        }
    }
}
