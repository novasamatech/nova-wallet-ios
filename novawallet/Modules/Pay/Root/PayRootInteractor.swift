import Foundation

final class PayRootInteractor {
    weak var presenter: PayRootInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let shopRequiredChainId: ChainModel.Id
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        shopRequiredChainId: ChainModel.Id,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.shopRequiredChainId = shopRequiredChainId
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension PayRootInteractor {
    func startSetup() {
        let fetchChainWrapper = chainRegistry.asyncWaitChainWrapper(for: shopRequiredChainId)

        execute(
            wrapper: fetchChainWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.completeSetup()
            case let .failure(error):
                self?.logger.error("Unexpected failure: \(error)")
            }
        }
    }

    func completeSetup() {
        eventCenter.add(observer: self, dispatchIn: .main)

        presenter?.didCompleteSetup()
    }
}

extension PayRootInteractor: PayRootInteractorInputProtocol {
    func setup() {
        startSetup()
    }
}

extension PayRootInteractor: EventVisitorProtocol {
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        presenter?.didChangeWallet()
    }
}
