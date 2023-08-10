import Foundation

final class StakingTypeWireframe: StakingTypeWireframeProtocol {
    func complete(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
