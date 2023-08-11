import Foundation

final class StakingSelectPoolWireframe: StakingSelectPoolWireframeProtocol {
    func complete(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
