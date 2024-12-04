import UIKit
import Operation_iOS
import BigInt
import SubstrateSdk

final class SwapSetupInteractor: SwapBaseInteractor {
    let storageRepository: AnyDataProviderRepository<ChainStorageItem>

    private var canPayFeeInAssetCall = CancellableCallStore()

    private var remoteSubscription: CallbackBatchStorageSubscription<BatchStorageSubscriptionRawResult>?

    init(
        state: SwapTokensFlowStateProtocol,
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
            state: state,
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

        let wrapper = assetsExchangeService.canPayFee(in: asset)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: canPayFeeInAssetCall,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(isFeeSupported):
                self?.presenter?.didReceiveCanPayFeeInPayAsset(
                    isFeeSupported,
                    chainAssetId: asset.chainAssetId
                )
            case let .failure(error):
                self?.logger.error("Unexpected error: \(error)")
                self?.presenter?.didReceiveCanPayFeeInPayAsset(false, chainAssetId: asset.chainAssetId)
            }
        }
    }

    private func clearRemoteSubscription() {
        remoteSubscription?.unsubscribe()
        remoteSubscription = nil
    }

    private func setupRemoteSubscription(for chain: ChainModel) {
        guard
            let accountId = selectedWallet.fetch(for: chain.accountRequest())?.accountId,
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return
        }

        do {
            let localKeyFactory = LocalStorageKeyFactory()

            let accountInfoKey = try localKeyFactory.createFromStoragePath(
                SystemPallet.accountPath,
                accountId: accountId,
                chainId: chain.chainId
            )

            let accountInfoRequest = BatchStorageSubscriptionRequest(
                innerRequest: MapSubscriptionRequest(
                    storagePath: SystemPallet.accountPath,
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
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }

    override func setupReQuoteSubscription(for _: ChainAssetId, assetOut _: ChainAssetId) {
        assetsExchangeService.subscribeRequoteService(
            for: self,
            notifyingIn: .main
        ) { [weak self] in
            self?.presenter?.didReceiveQuoteDataChanged()
        }
    }
}

extension SwapSetupInteractor: SwapSetupInteractorInputProtocol {
    func update(receiveChainAsset: ChainAsset?) {
        self.receiveChainAsset = receiveChainAsset
        receiveChainAsset.map {
            setReceiveChainAssetSubscriptions($0)
        }

        assetsExchangeService.throttleRequoteService()
    }

    func update(payChainAsset: ChainAsset?) {
        guard self.payChainAsset?.chainAssetId != payChainAsset?.chainAssetId else {
            return
        }

        clearRemoteSubscription()

        self.payChainAsset = payChainAsset

        if let payChainAsset = payChainAsset {
            setupRemoteSubscription(for: payChainAsset.chain)

            setPayChainAssetSubscriptions(payChainAsset)
            provideCanPayFee(for: payChainAsset)
        }

        assetsExchangeService.throttleRequoteService()
    }

    func update(feeChainAsset: ChainAsset?) {
        self.feeChainAsset = feeChainAsset
        feeChainAsset.map {
            setFeeChainAssetSubscriptions($0)
        }
    }
}
