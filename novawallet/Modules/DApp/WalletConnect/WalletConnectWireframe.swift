import Foundation

final class WalletConnectWireframe: WalletConnectWireframeProtocol {
    func showScan(from view: WalletConnectViewProtocol?, delegate: URIScanDelegate) {
        guard let scanView = URIScanViewFactory.createScan(for: delegate, context: nil) else {
            return
        }

        view?.controller.present(scanView.controller, animated: true)
    }
}
