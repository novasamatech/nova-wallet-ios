import Foundation

final class TinderGovSetupWireframe: TinderGovSetupWireframeProtocol {
    func showTinderGov(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.dismiss(animated: true)
    }
}
