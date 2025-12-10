import Foundation

extension AddAccount {
    final class PVWelcomeWireframe: PVWelcomeWireframeProtocol {
        func showScanQR(
            from view: PVWelcomeViewProtocol?,
            type: ParitySignerType
        ) {
            guard let scanView = PVScanViewFactory.createAddAccountView(with: type) else {
                return
            }

            view?.controller.navigationController?.pushViewController(scanView.controller, animated: true)
        }
    }
}
