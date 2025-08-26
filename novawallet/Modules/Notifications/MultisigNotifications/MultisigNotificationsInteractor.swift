import Foundation
import Operation_iOS

final class MultisigNotificationsInteractor {
    weak var presenter: MultisigNotificationsInteractorOutputProtocol?

    let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    let callStore = CancellableCallStore()

    init(
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.walletRepository = walletRepository
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        callStore.cancel()
    }
}

// MARK: - Private

extension MultisigNotificationsInteractor {
    func provideWallets() {
        let fetchOperation = walletRepository.fetchAllOperation(with: .init())

        execute(
            operation: fetchOperation,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(wallets):
                self?.presenter?.didReceive(multisigWallets: wallets)
            case let .failure(error):
                self?.logger.error("Failed to fetch wallets: \(error)")
            }
        }
    }
}

// MARK: - MultisigNotificationsInteractorInputProtocol

extension MultisigNotificationsInteractor: MultisigNotificationsInteractorInputProtocol {
    func setup() {
        provideWallets()
    }
}
