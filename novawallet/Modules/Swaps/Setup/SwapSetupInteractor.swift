import UIKit
import Operation_iOS
import BigInt
import SubstrateSdk

final class SwapSetupInteractor: SwapBaseInteractor {
    let storageRepository: AnyDataProviderRepository<ChainStorageItem>

    private var canPayFeeInAssetCall = CancellableCallStore()

    private var remoteSubscription: CallbackBatchStorageSubscription<BatchStorageSubscriptionRawResult>?

    init(
        flowState: AssetConversionFlowFacadeProtocol,
        assetsExchangeGraphProvider: AssetsExchangeGraphProviding,
        chainRegistry: ChainRegistryProtocol,
        assetStorageFactory: AssetStorageInfoOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        storageRepository: AnyDataProviderRepository<ChainStorageItem>,
        currencyManager: CurrencyManagerProtocol,
        selectedWallet: MetaAccountModel,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.storageRepository = storageRepository

        super.init(
            flowState: flowState,
            assetsExchangeGraphProvider: assetsExchangeGraphProvider,
            chainRegistry: chainRegistry,
            assetStorageFactory: assetStorageFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            currencyManager: currencyManager,
            selectedWallet: selectedWallet,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    weak var presenter: SwapSetupInteractorOutputProtocol? {
        basePresenter as? SwapSetupInteractorOutputProtocol
    }

    private var receiveChainAsset: ChainAsset? {
        didSet {
            updateSubscriptions(activeChainAssets: activeChainAssets)
        }
    }

    private var payChainAsset: ChainAsset? {
        didSet {
            updateSubscriptions(activeChainAssets: activeChainAssets)
        }
    }

    private var feeChainAsset: ChainAsset? {
        didSet {
            updateSubscriptions(activeChainAssets: activeChainAssets)
        }
    }

    private var activeChainAssets: Set<ChainAssetId> {
        Set(
            [
                receiveChainAsset?.chainAssetId,
                payChainAsset?.chainAssetId,
                feeChainAsset?.chainAssetId,
                feeChainAsset?.chain.utilityChainAssetId()
            ].compactMap { $0 }
        )
    }

    deinit {
        canPayFeeInAssetCall.cancel()
        clearRemoteSubscription()
    }

    private func provideCanPayFee(for asset: ChainAsset) {
        canPayFeeInAssetCall.cancel()

        // we currently don't allow to pay for swaps in non native token for proxy
        guard selectedWallet.type != .proxied else {
            presenter?.didReceiveCanPayFeeInPayAsset(false, chainAssetId: asset.chainAssetId)
            return
        }

        let wrapper = assetConversionAggregator.createCanPayFeeWrapper(in: asset)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: canPayFeeInAssetCall,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(canPayFee):
                self?.presenter?.didReceiveCanPayFeeInPayAsset(canPayFee, chainAssetId: asset.chainAssetId)
            case let .failure(error):
                self?.presenter?.didReceive(setupError: .payAssetSetFailed(error))
            }
        }
    }

    private func clearRemoteSubscription() {
        remoteSubscription?.unsubscribe()
        remoteSubscription = nil
    }

    private func setupRemoteSubscription(for chain: ChainModel) throws {
        guard
            let accountId = selectedWallet.fetch(for: chain.accountRequest())?.accountId,
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return
        }

        let localKeyFactory = LocalStorageKeyFactory()

        let accountInfoKey = try localKeyFactory.createFromStoragePath(
            .account,
            accountId: accountId,
            chainId: chain.chainId
        )
        let accountInfoRequest = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: .account,
                localKey: accountInfoKey,
                keyParamClosure: {
                    BytesCodable(wrappedValue: accountId)
                }
            ),
            mappingKey: nil
        )

        remoteSubscription = CallbackBatchStorageSubscription(
            requests: [accountInfoRequest],
            connection: connection,
            runtimeService: runtimeService,
            repository: storageRepository,
            operationQueue: operationQueue,
            callbackQueue: .main,
            callbackClosure: { _ in
                // we are listening remote subscription via database
            }
        )

        remoteSubscription?.subscribe()
    }

    override func updateChain(with newChain: ChainModel) {
        let oldChainId = currentChain?.chainId

        super.updateChain(with: newChain)

        if newChain.chainId != oldChainId {
            do {
                clearRemoteSubscription()
                try setupRemoteSubscription(for: newChain)
            } catch {
                presenter?.didReceive(setupError: .remoteSubscription(error))
            }
        }
    }

    override func setupReQuoteSubscription(for assetIn: ChainAssetId, assetOut: ChainAssetId) {
        if
            let reQuoteService = flowState.getReQuoteService(for: assetIn, assetOut: assetOut),
            !reQuoteService.hasSubscription(for: self) {
            reQuoteService.subscribeSyncState(
                self,
                queue: .main
            ) { [weak self] oldIsSyncing, newIsSyncing in
                if oldIsSyncing, !newIsSyncing {
                    self?.presenter?.didReceiveQuoteDataChanged()
                }
            }
        }
    }
}

extension SwapSetupInteractor: SwapSetupInteractorInputProtocol {
    func update(receiveChainAsset: ChainAsset?) {
        self.receiveChainAsset = receiveChainAsset
        receiveChainAsset.map {
            set(receiveChainAsset: $0)
        }
    }

    func update(payChainAsset: ChainAsset?) {
        self.payChainAsset = payChainAsset

        if let payChainAsset = payChainAsset {
            set(payChainAsset: payChainAsset)
            provideCanPayFee(for: payChainAsset)
        }
    }

    func update(feeChainAsset: ChainAsset?) {
        self.feeChainAsset = feeChainAsset
        feeChainAsset.map {
            set(feeChainAsset: $0)
        }
    }

    func retryRemoteSubscription() {
        guard let chain = currentChain else {
            return
        }

        do {
            clearRemoteSubscription()
            try setupRemoteSubscription(for: chain)
        } catch {
            presenter?.didReceive(setupError: .remoteSubscription(error))
        }
    }
}
