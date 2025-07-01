import UIKit
import Operation_iOS
import SubstrateSdk

class MultisigOperationConfirmInteractor {
    weak var presenter: MultisigOperationConfirmInteractorOutputProtocol?

    let chain: ChainModel
    let multisigWallet: MetaAccountModel
    let pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let signatoryRepository: MultisigSignatoryRepositoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private(set) var operation: Multisig.PendingOperation
    private(set) var extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol?
    private(set) var signer: SigningWrapperProtocol?
    private(set) var call: AnyRuntimeCall?

    private var operationProvider: StreamableProvider<Multisig.PendingOperation>?
    private var callProcessingStore = CancellableCallStore()

    init(
        operation: Multisig.PendingOperation,
        chain: ChainModel,
        multisigWallet: MetaAccountModel,
        signatoryRepository: MultisigSignatoryRepositoryProtocol,
        pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.operation = operation
        self.chain = chain
        self.multisigWallet = multisigWallet
        self.signatoryRepository = signatoryRepository
        self.pendingMultisigLocalSubscriptionFactory = pendingMultisigLocalSubscriptionFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.signingWrapperFactory = signingWrapperFactory
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func didSetupSignatories() {
        fatalError("Must be overriden by subsclass")
    }

    func didUpdateOperation() {
        fatalError("Must be overriden by subsclass")
    }

    func didProcessCall() {
        fatalError("Must be overriden by subsclass")
    }

    func doConfirm() {
        fatalError("Must be overriden by subsclass")
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

        extrinsicOperationFactory = extrinsicServiceFactory.createOperationFactory(
            account: signatoryAccount.chainAccount,
            chain: chain
        )

        signer = signingWrapperFactory.createSigningWrapper(
            for: signatoryAccount.metaId,
            accountResponse: signatoryAccount.chainAccount
        )

        logger.debug("Did setup current signatory")

        didSetupSignatories()
    }

    func processCallDataIfNeeded() {
        guard
            call == nil,
            !callProcessingStore.hasCall,
            let callData = operation.call else {
            return
        }

        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)
            let wrapper: CompoundOperationWrapper<AnyRuntimeCall> = runtimeProvider.createDecodingWrapper(
                for: callData,
                of: GenericType.call.name
            )

            executeCancellable(
                wrapper: wrapper,
                inOperationQueue: operationQueue,
                backingCallIn: callProcessingStore,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(call):
                    self?.call = call
                    self?.didProcessCall()
                case let .failure(error):
                    self?.presenter?.didReceiveError(.callProcessingFailed(error))
                }
            }

        } catch {
            presenter?.didReceiveError(.callProcessingFailed(error))
        }
    }
}

extension MultisigOperationConfirmInteractor: MultisigOperationConfirmInteractorInputProtocol {
    func setup() {
        setupSignatories()

        operationProvider = subscribePendingOperation(identifier: operation.identifier)
    }

    func confirm() {
        doConfirm()
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
            if let item {
                operation = item
            }

            didUpdateOperation()
            processCallDataIfNeeded()

            presenter?.didReceiveOperation(item)
        case let .failure(error):
            logger.error("Unexpected error: \(error)")
        }
    }
}
