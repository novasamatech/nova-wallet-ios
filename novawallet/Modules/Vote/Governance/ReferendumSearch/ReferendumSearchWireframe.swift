import Foundation

final class ReferendumSearchWireframe: ReferendumSearchWireframeProtocol {
    func finish(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
