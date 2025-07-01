import UIKit
import Operation_iOS

final class MultisigOperationConfirmInteractor {
    weak var presenter: MultisigOperationConfirmInteractorOutputProtocol?

    let operationId: String
    let chain: ChainModel
    let multisigWallet: MetaAccountModel
    let pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let callWeightEstimator: CallWeightEstimatingFactoryProtocol
    let signatoryRepository: MultisigSignatoryRepositoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var operationProvider: StreamableProvider<Multisig.PendingOperation>?
    private var extrinsicService: ExtrinsicServiceProtocol?
    private var signer: SigningWrapperProtocol?

    init(
        operationId: String,
        chain: ChainModel,
        multisigWallet: MetaAccountModel,
        signatoryRepository: MultisigSignatoryRepositoryProtocol,
        pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        callWeightEstimator: CallWeightEstimatingFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.operationId = operationId
        self.chain = chain
        self.multisigWallet = multisigWallet
        self.signatoryRepository = signatoryRepository
        self.pendingMultisigLocalSubscriptionFactory = pendingMultisigLocalSubscriptionFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.signingWrapperFactory = signingWrapperFactory
        self.chainRegistry = chainRegistry
        self.callWeightEstimator = callWeightEstimator
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension MultisigOperationConfirmInteractor {
    func setupSignatories() {
        guard let multisig = multisigWallet.multisigAccount?.multisig else {
            logger.error("Multisig expected here")
            return
        }

        let fetchWrapper = signatoryRepository.fetchSignatories(
            for: multisig,
            chain: chain
        )

        execute(
            wrapper: fetchWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(signatories):
                self?.setupCurrentSignatory(from: signatories)
                self?.presenter?.didReceiveSignatories(signatories)
            case let .failure(error):
                self?.presenter?.didReceiveError(.signatoriesFetchFailed(error))
            }
        }
    }

    func setupCurrentSignatory(from signatories: [Multisig.Signatory]) {
        guard let signatoryAccount = signatories.findSignatory(
            for: multisigWallet
        )?.localAccount else {
            logger.error("No local signatory found")
            return
        }

        extrinsicService = extrinsicServiceFactory.createService(
            account: signatoryAccount.chainAccount,
            chain: chain
        )

        signer = signingWrapperFactory.createSigningWrapper(
            for: signatoryAccount.metaId,
            accountResponse: signatoryAccount.chainAccount
        )

        logger.debug("Did setup current signatory")
    }
}

extension MultisigOperationConfirmInteractor: MultisigOperationConfirmInteractorInputProtocol {
    func setup() {
        setupSignatories()

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
