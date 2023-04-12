import Foundation

final class WalletConnectPresenter {
    weak var view: WalletConnectViewProtocol?
    let wireframe: WalletConnectWireframeProtocol
    let interactor: WalletConnectInteractorInputProtocol

    let logger: LoggerProtocol

    init(
        interactor: WalletConnectInteractorInputProtocol,
        wireframe: WalletConnectWireframeProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
    }
}

extension WalletConnectPresenter: WalletConnectPresenterProtocol {
    func setup() {}

    func showScan() {
        wireframe.showScan(from: view, delegate: self)
    }
}

extension WalletConnectPresenter: WalletConnectInteractorOutputProtocol {}

extension WalletConnectPresenter: URIScanDelegate {
    func uriScanDidReceive(uri: String, context _: AnyObject?) {
        logger.debug("Wallet Connect URI: \(uri)")
    }
}
