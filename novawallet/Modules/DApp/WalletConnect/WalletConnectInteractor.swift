import UIKit
import WalletConnectSwiftV2

final class WalletConnectInteractor {
    weak var presenter: WalletConnectInteractorOutputProtocol?

    let service: WalletConnectServiceProtocol
    let logger: LoggerProtocol

    init(service: WalletConnectServiceProtocol, logger: LoggerProtocol) {
        self.service = service
        self.logger = logger
    }

    deinit {
        service.throttle()
    }
}

extension WalletConnectInteractor: WalletConnectInteractorInputProtocol {
    func setup() {
        service.delegate = self
        service.setup()
    }

    func connect(uri: String) {
        service.connect(uri: uri)
    }
}

extension WalletConnectInteractor: WalletConnectServiceDelegate {
    func walletConnect(service _: WalletConnectServiceProtocol, proposal: Session.Proposal) {
        logger.debug("Proposal: \(proposal)")
    }

    func walletConnect(service _: WalletConnectServiceProtocol, establishedSession: Session) {
        logger.debug("New session: \(establishedSession)")
    }

    func walletConnect(service _: WalletConnectServiceProtocol, request: Request) {
        logger.debug("New session: \(request)")
    }

    func walletConnect(service _: WalletConnectServiceProtocol, error: WalletConnectServiceError) {
        logger.error("Error: \(error)")
    }
}
