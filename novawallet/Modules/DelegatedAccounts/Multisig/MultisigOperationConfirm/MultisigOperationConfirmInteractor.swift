import UIKit
import Operation_iOS
import SubstrateSdk

class MultisigOperationConfirmInteractor: AnyProviderAutoCleaning {
    weak var presenter: MultisigOperationConfirmInteractorOutputProtocol?

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let pendingOperationProvider: MultisigOperationProviderProxyProtocol
    let remoteOperationFactory: MultisigStorageOperationFactoryProtocol

    let chain: ChainModel
    let multisigWallet: MetaAccountModel
    let operationChainAsset: ChainAsset?
    let assetInfoOperationFactory: AssetStorageInfoOperationFactoryProtocol
    let balanceRemoteSubscriptionFactory: WalletRemoteSubscriptionWrapperProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let signatoryRepository: MultisigSignatoryRepositoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private(set) var operation: Multisig.PendingOperationProxyModel
    private(set) var extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol?
    private(set) var extrinsicSubmissionMonitor: ExtrinsicSubmitMonitorFactoryProtocol?
    private(set) var signer: SigningWrapperProtocol?
    private(set) var call: AnyRuntimeCall?

    private var assetInfo: AssetStorageInfo?
    private var assetRemoteSubscriptionId: UUID?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var utilityAssetPriceProvider: StreamableProvider<PriceData>?
    private var operationAssetPriceProvider: StreamableProvider<PriceData>?
    private var callProcessingStore = CancellableCallStore()

    init(
        operation: Multisig.PendingOperationProxyModel,
        chain: ChainModel,
        multisigWallet: MetaAccountModel,
        operationChainAsset: ChainAsset?,
        remoteOperationFactory: MultisigStorageOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        balanceRemoteSubscriptionFactory: WalletRemoteSubscriptionWrapperProtocol,
        signatoryRepository: MultisigSignatoryRepositoryProtocol,
        pendingOperationProvider: MultisigOperationProviderProxyProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        assetInfoOperationFactory: AssetStorageInfoOperationFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.operation = operation
        self.chain = chain
        self.multisigWallet = multisigWallet
        self.operationChainAsset = operationChainAsset
        self.remoteOperationFactory = remoteOperationFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.balanceRemoteSubscriptionFactory = balanceRemoteSubscriptionFactory
        self.signatoryRepository = signatoryRepository
        self.pendingOperationProvider = pendingOperationProvider
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.signingWrapperFactory = signingWrapperFactory
        self.assetInfoOperationFactory = assetInfoOperationFactory
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.logger = logger
        self.currencyManager = currencyManager

        call = operation.formattedModel?.decoded
    }

    deinit {
        clearBalanceRemoteSubscription()
    }

    func setup() {
        setupSignatories()

        pendingOperationProvider.subscribePendingOperation(
            identifier: operation.operation.identifier,
            handler: self
        )

        deriveAssetInfoAndProvideBalance()

        setupUtilityAssetPriceSubscription()
        setupOperationAssetPriceSubscriptionIfNeeded()
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

    func doConfirm(with _: MultisigPallet.MultisigDefinition) {
        fatalError("Must be overriden by subsclass")
    }

    func doEstimateFee() {
        fatalError("Must be overriden by subsclass")
    }
}

// MARK: - Private

private extension MultisigOperationConfirmInteractor {
    func setupSignatories() {
        guard let multisig = multisigWallet.getMultisig(for: chain) else {
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
            for: multisigWallet,
            chain: chain
        )?.localAccount else {
            logger.error("No local signatory found")
            return
        }

        extrinsicOperationFactory = extrinsicServiceFactory.createOperationFactory(
            account: signatoryAccount.chainAccount,
            chain: chain
        )

        extrinsicSubmissionMonitor = extrinsicServiceFactory.createExtrinsicSubmissionMonitor(
            with: extrinsicServiceFactory.createService(
                account: signatoryAccount.chainAccount,
                chain: chain
            )
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
            let callData = operation.operation.call else {
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

    func deriveAssetInfoAndProvideBalance() {
        do {
            guard let asset = chain.utilityAsset() else {
                logger.error("No utility asset in chain")
                return
            }

            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)

            let assetInfoWrapper = assetInfoOperationFactory.createStorageInfoWrapper(
                from: asset,
                runtimeProvider: runtimeProvider
            )

            execute(
                wrapper: assetInfoWrapper,
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(assetInfo):
                    self?.assetInfo = assetInfo
                    self?.setupSignatoryLocalBalanceSubsription()
                    self?.setupSignatoryRemoteBalanceSubsription()
                    self?.provideBalanceExistense()
                case let .failure(error):
                    self?.presenter?.didReceiveError(.balanceInfoFailed(error))
                }
            }

        } catch {
            presenter?.didReceiveError(.balanceInfoFailed(error))
        }
    }

    func provideBalanceExistense() {
        do {
            guard let asset = chain.utilityAsset() else {
                logger.error("No utility asset in chain")
                return
            }

            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)

            let assetInfoWrapper = assetInfoOperationFactory.createAssetBalanceExistenceOperation(
                chainId: chain.chainId,
                asset: asset,
                runtimeProvider: runtimeProvider,
                operationQueue: operationQueue
            )

            execute(
                wrapper: assetInfoWrapper,
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(assetBalanceExistence):
                    self?.presenter?.didReceiveAssetBalanceExistense(assetBalanceExistence)
                case let .failure(error):
                    self?.presenter?.didReceiveError(.balanceInfoFailed(error))
                }
            }
        } catch {
            presenter?.didReceiveError(.balanceInfoFailed(error))
        }
    }

    func setupUtilityAssetPriceSubscription() {
        clear(streamableProvider: &utilityAssetPriceProvider)

        guard
            let asset = chain.utilityAsset(),
            let priceId = asset.priceId
        else {
            return
        }

        utilityAssetPriceProvider = subscribeToPrice(
            for: priceId,
            currency: selectedCurrency
        )
    }

    func setupOperationAssetPriceSubscriptionIfNeeded() {
        clear(streamableProvider: &operationAssetPriceProvider)

        guard
            case let amountChainAsset = operation.formattedModel?.definition.amountAsset,
            amountChainAsset != chain.utilityChainAsset(),
            let priceId = amountChainAsset?.asset.priceId
        else {
            return
        }

        operationAssetPriceProvider = subscribeToPrice(
            for: priceId,
            currency: selectedCurrency
        )
    }

    func setupSignatoryLocalBalanceSubsription() {
        clear(streamableProvider: &balanceProvider)

        guard
            let multisig = multisigWallet.getMultisig(
                for: chain
            ),
            let asset = chain.utilityAsset() else {
            logger.error("Multisig and asset expected")
            return
        }

        balanceProvider = subscribeToAssetBalanceProvider(
            for: multisig.signatory,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
    }

    func setupSignatoryRemoteBalanceSubsription() {
        guard
            let multisig = multisigWallet.getMultisig(for: chain),
            let asset = chain.utilityChainAsset(),
            let assetInfo else {
            logger.error("Multisig, asset and info expected here")
            return
        }

        assetRemoteSubscriptionId = balanceRemoteSubscriptionFactory.subscribe(
            using: assetInfo,
            accountId: multisig.signatory,
            chainAsset: asset,
            completion: nil
        )
    }

    func clearBalanceRemoteSubscription() {
        guard
            let assetInfo,
            let assetRemoteSubscriptionId,
            let multisig = multisigWallet.getMultisig(for: chain),
            let asset = chain.utilityChainAsset() else {
            return
        }

        balanceRemoteSubscriptionFactory.unsubscribe(
            from: assetRemoteSubscriptionId,
            assetStorageInfo: assetInfo,
            accountId: multisig.signatory,
            chainAssetId: asset.chainAssetId,
            completion: nil
        )
    }
}

// MARK: - MultisigOperationConfirmInteractorInputProtocol

extension MultisigOperationConfirmInteractor: MultisigOperationConfirmInteractorInputProtocol {
    func confirm() {
        do {
            let callHash = operation.operation.callHash
            let chainId = operation.operation.chainId
            let connection = try chainRegistry.getConnectionOrError(for: chainId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let opDefinitionWrapper = remoteOperationFactory.fetchPendingOperation(
                for: operation.operation.multisigAccountId,
                callHashClosure: {
                    callHash
                },
                connection: connection,
                runtimeProvider: runtimeProvider
            )

            execute(
                wrapper: opDefinitionWrapper,
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(optDefinition):
                    if let definition = optDefinition {
                        self?.doConfirm(with: definition)
                    } else {
                        self?.presenter?.didReceiveError(.noOperationExists)
                    }
                case let .failure(error):
                    self?.presenter?.didReceiveError(.submissionError(error))
                }
            }
        } catch {
            presenter?.didReceiveError(.submissionError(error))
        }
    }

    func refreshFee() {
        doEstimateFee()
    }
}

// MARK: - MultisigOperationsLocalStorageSubscriber

extension MultisigOperationConfirmInteractor: MultisigOperationProviderHandlerProtocol {
    func handleMultisigPendingOperation(
        result: Result<Multisig.PendingOperationProxyModel?, Error>,
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

// MARK: - WalletLocalSubscriptionHandler

extension MultisigOperationConfirmInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            presenter?.didReceiveSignatoryBalance(balance)
        case let .failure(error):
            logger.error("Can't load local balance: \(error)")
        }
    }
}

// MARK: - PriceLocalSubscriptionHandler

extension MultisigOperationConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, any Error>,
        priceId: AssetModel.PriceId
    ) {
        let priceData = try? result.get()

        guard priceId == chain.utilityAsset()?.priceId else {
            presenter?.didReceiveOperationAssetPrice(priceData)
            return
        }

        presenter?.didReceiveUtilityAssetPrice(priceData)

        if priceId == operationChainAsset?.asset.priceId {
            presenter?.didReceiveOperationAssetPrice(priceData)
        }
    }
}

// MARK: - SelectedCurrencyDepending

extension MultisigOperationConfirmInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        setupUtilityAssetPriceSubscription()
        setupOperationAssetPriceSubscriptionIfNeeded()
    }
}
