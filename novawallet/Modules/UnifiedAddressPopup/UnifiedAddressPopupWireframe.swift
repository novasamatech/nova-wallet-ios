import Foundation

final class UnifiedAddressPopupWireframe: UnifiedAddressPopupWireframeProtocol {
    func close(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
