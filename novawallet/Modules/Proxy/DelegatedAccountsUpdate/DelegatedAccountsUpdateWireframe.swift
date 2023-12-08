import Foundation

final class DelegatedAccountsUpdateWireframe: DelegatedAccountsUpdateWireframeProtocol {
    func close(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
