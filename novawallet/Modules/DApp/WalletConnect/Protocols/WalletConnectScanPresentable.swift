import Foundation

protocol WalletConnectScanPresentable: AnyObject {
    func showScan(from view: ControllerBackedProtocol?, delegate: URIScanDelegate)
    func hideUriScanAnimated(from view: ControllerBackedProtocol?, completion: @escaping () -> Void)
}

extension WalletConnectScanPresentable {
    func showScan(from view: ControllerBackedProtocol?, delegate: URIScanDelegate) {
        guard let scanView = URIScanViewFactory.createScan(for: delegate, context: nil) else {
            return
        }

        view?.controller.present(scanView.controller, animated: true)
    }

    func hideUriScanAnimated(from view: ControllerBackedProtocol?, completion: @escaping () -> Void) {
        view?.controller.dismiss(animated: true, completion: completion)
    }
}
