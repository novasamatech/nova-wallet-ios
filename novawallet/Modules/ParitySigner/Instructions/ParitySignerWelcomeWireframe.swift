import Foundation

final class ParitySignerWelcomeWireframe: ParitySignerWelcomeWireframeProtocol {
    func showScanQR(from view: ParitySignerWelcomeViewProtocol?) {
        guard let scanView = ParitySignerScanViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(scanView.controller, animated: true)
    }
}
