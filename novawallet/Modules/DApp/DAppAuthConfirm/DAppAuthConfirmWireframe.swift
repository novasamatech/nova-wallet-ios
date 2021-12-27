import Foundation

final class DAppAuthConfirmWireframe: DAppAuthConfirmWireframeProtocol {
    func close(from view: DAppAuthConfirmViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
