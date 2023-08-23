import Foundation

final class NominationPoolSearchWireframe: NominationPoolSearchWireframeProtocol {
    func complete(from view: ControllerBackedProtocol?) {
        if let stakingType = view?.controller.navigationController?.viewControllers.first(
            where: { $0 is StakingTypeViewProtocol }) as? StakingTypeViewProtocol {
            view?.controller.navigationController?.popToViewController(
                stakingType.controller,
                animated: true
            )
        }
    }
}
