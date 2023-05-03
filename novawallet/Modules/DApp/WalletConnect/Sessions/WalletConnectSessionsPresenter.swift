import Foundation

final class WalletConnectSessionsPresenter {
    weak var view: WalletConnectSessionsViewProtocol?
    let wireframe: WalletConnectSessionsWireframeProtocol
    let interactor: WalletConnectSessionsInteractorInputProtocol

    let logger: LoggerProtocol

    init(
        interactor: WalletConnectSessionsInteractorInputProtocol,
        wireframe: WalletConnectSessionsWireframeProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
    }
}

extension WalletConnectSessionsPresenter: WalletConnectSessionsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func showScan() {
        wireframe.showScan(from: view, delegate: self)
    }
}

extension WalletConnectSessionsPresenter: WalletConnectSessionsInteractorOutputProtocol {}

extension WalletConnectSessionsPresenter: URIScanDelegate {
    func uriScanDidReceive(uri: String, context _: AnyObject?) {
        logger.debug("Wallet Connect URI: \(uri)")

        wireframe.hideUriScanAnimated(from: view) { [weak self] in
            self?.interactor.connect(uri: uri)
        }
    }
}
