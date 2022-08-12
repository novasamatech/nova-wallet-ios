import Foundation

extension AddAccount {
    final class ParitySignerWelcomeWireframe: ParitySignerWelcomeWireframeProtocol {
        func showScanQR(from view: ParitySignerWelcomeViewProtocol?) {
            guard let scanView = ParitySignerScanViewFactory.createAddAccountView() else {
                return
            }

            view?.controller.navigationController?.pushViewController(scanView.controller, animated: true)
        }
    }
}
