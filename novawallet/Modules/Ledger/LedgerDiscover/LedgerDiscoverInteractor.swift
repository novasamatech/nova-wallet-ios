import UIKit

final class LedgerDiscoverInteractor {
    weak var presenter: LedgerDiscoverInteractorOutputProtocol?

    let ledgerConnection: LedgerConnectionManagerProtocol

    init(ledgerConnection: LedgerConnectionManagerProtocol) {
        self.ledgerConnection = ledgerConnection
    }

    deinit {
        ledgerConnection.delegate = nil
        ledgerConnection.stop()
    }
}

extension LedgerDiscoverInteractor: LedgerDiscoverInteractorInputProtocol {
    func setup() {
        ledgerConnection.delegate = self
        ledgerConnection.start()
    }
}

extension LedgerDiscoverInteractor: LedgerConnectionManagerDelegate {
    func ledgerConnection(manager _: LedgerConnectionManagerProtocol, didFailToConnect _: Error) {}

    func ledgerConnection(manager _: LedgerConnectionManagerProtocol, didDiscover device: LedgerDeviceProtocol) {
        presenter?.didDiscover(device: device)
    }

    func ledgerConnection(manager _: LedgerConnectionManagerProtocol, didDisconnect _: LedgerDeviceProtocol, error _: Error?) {}
}
