import UIKit
import Operation_iOS

final class MultisigOperationConfirmInteractor {
    weak var presenter: MultisigOperationConfirmInteractorOutputProtocol?

    let operationId: String
    let multisigWallet: MetaAccountModel
    let signatorWalletRepository: AnyDataProviderRepository<MetaAccountModel>
    let pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let callWeightEstimator: CallWeightEstimatingFactoryProtocol
    let logger: LoggerProtocol

    private var operationProvider: StreamableProvider<Multisig.PendingOperation>?

    init(
        operationId: String,
        multisigWallet: MetaAccountModel,
        signatorWalletRepository: AnyDataProviderRepository<MetaAccountModel>,
        pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        callWeightEstimator: CallWeightEstimatingFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.operationId = operationId
        self.multisigWallet = multisigWallet
        self.signatorWalletRepository = signatorWalletRepository
        self.pendingMultisigLocalSubscriptionFactory = pendingMultisigLocalSubscriptionFactory
        self.chainRegistry = chainRegistry
        self.callWeightEstimator = callWeightEstimator
        self.logger = logger
    }
}

extension MultisigOperationConfirmInteractor: MultisigOperationConfirmInteractorInputProtocol {
    func setup() {
        operationProvider = subscribePendingOperation(identifier: operationId)
    }
}

extension MultisigOperationConfirmInteractor: MultisigOperationsLocalStorageSubscriber,
    MultisigOperationsLocalSubscriptionHandler {
    func handleMultisigPendingOperation(
        result: Result<Multisig.PendingOperation?, any Error>,
        identifier _: String
    ) {
        switch result {
        case let .success(item):
            presenter?.didReceiveOperation(item)
        case let .failure(error):
            logger.error("Unexpected error: \(error)")
        }
    }
}
