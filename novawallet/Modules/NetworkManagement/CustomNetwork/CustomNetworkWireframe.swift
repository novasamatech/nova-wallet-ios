import Foundation

final class CustomNetworkWireframe: CustomNetworkWireframeProtocol {
    func showPrevious(from view: CustomNetworkViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
