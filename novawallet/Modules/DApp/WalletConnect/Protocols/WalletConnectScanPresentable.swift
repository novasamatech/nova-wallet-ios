import Foundation

protocol WalletConnectScanPresentable: AnyObject {
    func showScan(from view: ControllerBackedProtocol?, delegate: URIScanDelegate)
    func hideUriScanAnimated(from view: ControllerBackedProtocol?, completion: @escaping () -> Void)
}

extension WalletConnectScanPresentable {
    func showScan(from view: ControllerBackedProtocol?, delegate: URIScanDelegate) {
        guard let scanView = URIScanViewFactory.createWalletConnectScan(for: delegate, context: nil) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: scanView.controller)

        view?.controller.present(navigationController, animated: true)
    }

    func hideUriScanAnimated(from view: ControllerBackedProtocol?, completion: @escaping () -> Void) {
        view?.controller.dismiss(animated: true, completion: completion)
    }
}
