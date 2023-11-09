import UIKit
import RobinHood
import BigInt
import SubstrateSdk

final class SwapSetupInteractor: SwapBaseInteractor {
    let xcmTransfersSyncService: XcmTransfersSyncServiceProtocol
    let storageRepository: AnyDataProviderRepository<ChainStorageItem>

    private var xcmTransfers: XcmTransfers?
    private var canPayFeeInAssetCall = CancellableCallStore()

    private var remoteSubscription: CallbackBatchStorageSubscription<BatchStorageSubscriptionRawResult>?
    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?

    init(
        xcmTransfersSyncService: XcmTransfersSyncServiceProtocol,
        assetConversionAggregatorFactory: AssetConversionAggregationFactoryProtocol,
        assetConversionFeeService: AssetConversionFeeServiceProtocol,
        chainRegistry: ChainRegistryProtocol,
        assetStorageFactory: AssetStorageInfoOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        storageRepository: AnyDataProviderRepository<ChainStorageItem>,
        currencyManager: CurrencyManagerProtocol,
        selectedWallet: MetaAccountModel,
        operationQueue: OperationQueue
    ) {
        self.xcmTransfersSyncService = xcmTransfersSyncService
        self.storageRepository = storageRepository

        super.init(
            assetConversionAggregator: assetConversionAggregatorFactory,
            assetConversionFeeService: assetConversionFeeService,
            chainRegistry: chainRegistry,
            assetStorageFactory: assetStorageFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            generalSubscriptionFactory: generalLocalSubscriptionFactory,
            currencyManager: currencyManager,
            selectedWallet: selectedWallet,
            operationQueue: operationQueue
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
        xcmTransfersSyncService.throttle()
        canPayFeeInAssetCall.cancel()
        clearRemoteSubscription()
    }

    private func setupXcmTransfersSyncService() {
        xcmTransfersSyncService.notificationCallback = { [weak self] result in
            switch result {
            case let .success(xcmTransfers):
                self?.xcmTransfers = xcmTransfers
                self?.provideAvailableTransfers()
            case let .failure(error):
                self?.presenter?.didReceive(setupError: .xcm(error))
            }
        }

        xcmTransfersSyncService.setup()
    }

    private func provideAvailableTransfers() {
        guard let xcmTransfers = xcmTransfers, let payChainAsset = payChainAsset else {
            presenter?.didReceiveAvailableXcm(origins: [], xcmTransfers: nil)
            return
        }

        let chainAssets = xcmTransfers.transferChainAssets(to: payChainAsset.chainAssetId)

        guard !chainAssets.isEmpty else {
            presenter?.didReceiveAvailableXcm(origins: [], xcmTransfers: xcmTransfers)
            return
        }

        let origins: [ChainAsset] = chainAssets.compactMap { chainAsset in
            guard
                chainAsset != payChainAsset.chainAssetId,
                let chain = chainRegistry.getChain(for: chainAsset.chainId),
                let asset = chain.asset(for: chainAsset.assetId)
            else {
                return nil
            }

            return ChainAsset(chain: chain, asset: asset)
        }

        presenter?.didReceiveAvailableXcm(origins: origins, xcmTransfers: xcmTransfers)
    }

    private func provideCanPayFee(for asset: ChainAsset) {
        canPayFeeInAssetCall.cancel()

        guard let utilityAssetId = asset.chain.utilityChainAssetId() else {
            presenter?.didReceiveCanPayFeeInPayAsset(false, chainAssetId: asset.chainAssetId)
            return
        }

        let wrapper = assetConversionAggregator.createAvailableDirectionsWrapper(for: asset)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: canPayFeeInAssetCall,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(chainAssetIds):
                let canPayFee = chainAssetIds.contains(utilityAssetId)
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

        let blockNumberKey = try localKeyFactory.createFromStoragePath(.blockNumber, chainId: chain.chainId)
        let blockNumberRequest = BatchStorageSubscriptionRequest(
            innerRequest: UnkeyedSubscriptionRequest(
                storagePath: .blockNumber,
                localKey: blockNumberKey
            ),
            mappingKey: nil
        )

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
            requests: [blockNumberRequest, accountInfoRequest],
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

    private func updateBlockNumberSubscription(for chain: ChainModel) {
        clear(dataProvider: &blockNumberSubscription)
        blockNumberSubscription = subscribeToBlockNumber(for: chain.chainId)
    }

    override func updateChain(with newChain: ChainModel) {
        let oldChainId = currentChain?.chainId

        super.updateChain(with: newChain)

        if newChain.chainId != oldChainId {
            updateBlockNumberSubscription(for: newChain)

            do {
                clearRemoteSubscription()
                try setupRemoteSubscription(for: newChain)
            } catch {
                presenter?.didReceive(setupError: .remoteSubscription(error))
            }
        }
    }

    override func setup() {
        super.setup()
        setupXcmTransfersSyncService()
    }

    override func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId: ChainModel.Id
    ) {
        switch result {
        case let .success(blockNumber):
            presenter?.didReceiveBlockNumber(blockNumber, chainId: chainId)
        case let .failure(error):
            presenter?.didReceive(setupError: .blockNumber(error))
        }
    }
}

extension SwapSetupInteractor: SwapSetupInteractorInputProtocol {
    func setupXcm() {
        setupXcmTransfersSyncService()
    }

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

        provideAvailableTransfers()
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

    func retryBlockNumberSubscription() {
        guard let chain = currentChain else {
            return
        }

        updateBlockNumberSubscription(for: chain)
    }
}
