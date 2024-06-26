import Foundation

final class GenericLedgerDiscoverInteractor: LedgerPerformOperationInteractor {
    var presenter: LedgerDiscoverInteractorOutputProtocol? {
        get {
            basePresenter as? LedgerDiscoverInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let ledgerApplication: GenericLedgerSubstrateApplicationProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        ledgerApplication: GenericLedgerSubstrateApplicationProtocol,
        ledgerConnection: LedgerConnectionManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.ledgerApplication = ledgerApplication
        self.operationQueue = operationQueue
        self.logger = logger

        super.init(ledgerConnection: ledgerConnection)
    }

    override func performOperation(using deviceId: UUID) {
        let wrapper = ledgerApplication.getAccountWrapper(
            for: deviceId,
            index: 0,
            addressPrefix: SubstrateConstants.genericAddressPrefix,
            displayVerificationDialog: false
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didReceiveConnection(result: .success(()), for: deviceId)
            case let .failure(error):
                self?.logger.error("Did receive error: \(error)")
                self?.presenter?.didReceiveConnection(result: .failure(error), for: deviceId)
            }
        }
    }
}
