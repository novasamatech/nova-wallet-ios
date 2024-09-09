import Foundation

final class TinderGovWireframe: TinderGovWireframeProtocol {
    func back(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
