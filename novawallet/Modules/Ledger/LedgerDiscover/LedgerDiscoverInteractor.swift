import UIKit

final class LedgerDiscoverInteractor {
    weak var presenter: LedgerDiscoverInteractorOutputProtocol?

    let ledgerConnection: LedgerConnectionManagerProtocol
    let ledgerApplication: LedgerApplicationProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        ledgerApplication: LedgerApplicationProtocol,
        ledgerConnection: LedgerConnectionManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.ledgerApplication = ledgerApplication
        self.ledgerConnection = ledgerConnection
        self.operationQueue = operationQueue
        self.logger = logger
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

    func connect(to deviceId: UUID) {
        // TODO: Provide chainId based on user selected network
        let wrapper = ledgerApplication.getAccountWrapper(
            for: deviceId,
            chainId: KnowChainId.polkadot,
            index: 0
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    _ = try wrapper.targetOperation.extractNoCancellableResultData()

                    self?.presenter?.didReceiveConnection(result: .success(()), for: deviceId)
                } catch {
                    self?.logger.error("Did receive error: \(error)")

                    self?.presenter?.didReceiveConnection(result: .failure(error), for: deviceId)
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension LedgerDiscoverInteractor: LedgerConnectionManagerDelegate {
    func ledgerConnection(manager _: LedgerConnectionManagerProtocol, didDiscover device: LedgerDeviceProtocol) {
        DispatchQueue.main.async { [weak self] in
            self?.presenter?.didDiscover(device: device)
        }
    }

    func ledgerConnection(manager _: LedgerConnectionManagerProtocol, didReceive error: LedgerDiscoveryError) {
        DispatchQueue.main.async { [weak self] in
            self?.presenter?.didReceiveSetup(error: error)
        }
    }
}
