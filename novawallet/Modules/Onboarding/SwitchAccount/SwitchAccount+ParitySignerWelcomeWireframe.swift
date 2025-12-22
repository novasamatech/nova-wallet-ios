import Foundation

extension SwitchAccount {
    final class PVWelcomeWireframe: PVWelcomeWireframeProtocol {
        func showScanQR(
            from view: PVWelcomeViewProtocol?,
            type: ParitySignerType
        ) {
            guard let scanView = PVScanViewFactory.createSwitchAccountView(with: type) else {
                return
            }

            view?.controller.navigationController?.pushViewController(scanView.controller, animated: true)
        }
    }
}
