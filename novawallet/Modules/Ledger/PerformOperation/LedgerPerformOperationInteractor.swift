import UIKit

class LedgerPerformOperationInteractor: LedgerPerformOperationInputProtocol {
    weak var basePresenter: LedgerPerformOperationOutputProtocol?

    let ledgerConnection: LedgerConnectionManagerProtocol

    init(ledgerConnection: LedgerConnectionManagerProtocol) {
        self.ledgerConnection = ledgerConnection
    }

    deinit {
        ledgerConnection.delegate = nil
        ledgerConnection.stop()
    }

    func setup() {
        ledgerConnection.delegate = self
        ledgerConnection.start()
    }

    func performOperation(using _: UUID) {
        assertionFailure("Child class must implement this method")
    }
}

extension LedgerPerformOperationInteractor: LedgerConnectionManagerDelegate {
    func ledgerConnection(manager _: LedgerConnectionManagerProtocol, didDiscover device: LedgerDeviceProtocol) {
        DispatchQueue.main.async { [weak self] in
            self?.basePresenter?.didDiscover(device: device)
        }
    }

    func ledgerConnection(manager _: LedgerConnectionManagerProtocol, didReceive error: LedgerDiscoveryError) {
        DispatchQueue.main.async { [weak self] in
            self?.basePresenter?.didReceiveSetup(error: error)
        }
    }
}
