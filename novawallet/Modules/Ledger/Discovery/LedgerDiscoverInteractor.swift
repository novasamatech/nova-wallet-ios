import Foundation

final class LedgerDiscoverInteractor: LedgerPerformOperationInteractor {
    var presenter: LedgerDiscoverInteractorOutputProtocol? {
        get {
            basePresenter as? LedgerDiscoverInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let chain: ChainModel
    let ledgerApplication: LedgerApplicationProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chain: ChainModel,
        ledgerApplication: LedgerApplicationProtocol,
        ledgerConnection: LedgerConnectionManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chain = chain
        self.ledgerApplication = ledgerApplication
        self.operationQueue = operationQueue
        self.logger = logger

        super.init(ledgerConnection: ledgerConnection)
    }

    override func performOperation(using deviceId: UUID) {
        let wrapper = ledgerApplication.getAccountWrapper(
            for: deviceId,
            chainId: chain.chainId,
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
