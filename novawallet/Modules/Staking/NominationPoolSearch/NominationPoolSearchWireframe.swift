import Foundation

final class NominationPoolSearchWireframe: NominationPoolSearchWireframeProtocol {
    func complete(from view: ControllerBackedProtocol?) {
        if let stakingType: StakingTypeViewProtocol = view?.controller.navigationController?.findTopView() {
            view?.controller.navigationController?.popToViewController(
                stakingType.controller,
                animated: true
            )
        }
    }
}
