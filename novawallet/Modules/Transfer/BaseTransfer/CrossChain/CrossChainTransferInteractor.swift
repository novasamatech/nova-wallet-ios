import Foundation
import Operation_iOS
import BigInt
import SubstrateSdk

private struct CrossChainAssetsStorageInfo {
    let originSending: AssetStorageInfo
    let originUtility: AssetStorageInfo?
    let destinationSending: AssetStorageInfo
    let destinationUtility: AssetStorageInfo?
}

class CrossChainTransferInteractor: RuntimeConstantFetching {
    private typealias SetupResult = (XcmTransferParties, CrossChainAssetsStorageInfo)

    weak var presenter: CrossChainTransferSetupInteractorOutputProtocol?

    let selectedAccount: ChainAccountResponse
    let xcmTransfers: XcmTransfers
    let originChainAsset: ChainAsset
    let destinationChainAsset: ChainAsset
    let chainRegistry: ChainRegistryProtocol
    let feeProxy: XcmExtrinsicFeeProxyProtocol
    let extrinsicService: XcmTransferServiceProtocol
    let resolutionFactory: XcmTransferResolutionFactoryProtocol
    let walletRemoteWrapper: WalletRemoteSubscriptionWrapperProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let substrateStorageFacade: StorageFacadeProtocol
    let fungibilityPreservationProvider: AssetFungibilityPreservationProviding
    let operationQueue: OperationQueue

    private lazy var callFactory = SubstrateCallFactory()
    private lazy var assetStorageInfoFactory = AssetStorageInfoOperationFactory()

    private var sendingAssetProvider: StreamableProvider<AssetBalance>?
    private var utilityAssetProvider: StreamableProvider<AssetBalance>?
    private var sendingAssetPriceProvider: StreamableProvider<PriceData>?
    private var utilityAssetPriceProvider: StreamableProvider<PriceData>?

    private var recepientAccountId: AccountId?

    private var setupCallStore = CancellableCallStore()

    private var assetsInfo: CrossChainAssetsStorageInfo?
    private(set) var transferParties: XcmTransferParties?

    private var sendingAssetSubscriptionId: UUID?
    private var utilityAssetSubscriptionId: UUID?

    private var recepientSendingAssetProvider: StreamableProvider<AssetBalance>?
    private var recepientUtilityAssetProvider: StreamableProvider<AssetBalance>?

    var isSendingUtility: Bool {
        originChainAsset.chain.utilityAssets().first?.assetId == originChainAsset.asset.assetId
    }

    var isReceivingUtility: Bool {
        destinationChainAsset.chain.utilityAssets().first?.assetId == destinationChainAsset.asset.assetId
    }

    private lazy var chainStorage: AnyDataProviderRepository<ChainStorageItem> = {
        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            substrateStorageFacade.createRepository()
        return AnyDataProviderRepository(storage)
    }()

    init(
        selectedAccount: ChainAccountResponse,
        xcmTransfers: XcmTransfers,
        originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        feeProxy: XcmExtrinsicFeeProxyProtocol,
        extrinsicService: XcmTransferServiceProtocol,
        resolutionFactory: XcmTransferResolutionFactoryProtocol,
        fungibilityPreservationProvider: AssetFungibilityPreservationProviding,
        walletRemoteWrapper: WalletRemoteSubscriptionWrapperProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.xcmTransfers = xcmTransfers
        self.originChainAsset = originChainAsset
        self.destinationChainAsset = destinationChainAsset
        self.chainRegistry = chainRegistry
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.resolutionFactory = resolutionFactory
        self.fungibilityPreservationProvider = fungibilityPreservationProvider
        self.walletRemoteWrapper = walletRemoteWrapper
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.substrateStorageFacade = substrateStorageFacade
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        setupCallStore.cancel()

        clearSendingAssetRemoteRecepientSubscription()
        clearUtilityAssetRemoteRecepientSubscriptions()
    }

    private func fetchAssetExistence(
        for assetStorageInfo: AssetStorageInfo,
        chainId: ChainModel.Id,
        asset: AssetModel,
        completionClosure: @escaping (Result<AssetBalanceExistence, Error>) -> Void
    ) {
        let wrapper = assetStorageInfoFactory.createAssetBalanceExistenceOperation(
            for: assetStorageInfo,
            chainId: chainId,
            asset: asset
        )

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let assetExistence = try wrapper.targetOperation.extractNoCancellableResultData()
                    completionClosure(.success(assetExistence))
                } catch {
                    completionClosure(.failure(error))
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func createAssetExtractionWrapper() -> CompoundOperationWrapper<CrossChainAssetsStorageInfo> {
        guard
            let originProvider = chainRegistry.getRuntimeProvider(for: originChainAsset.chain.chainId),
            let destinationProvider = chainRegistry.getRuntimeProvider(for: destinationChainAsset.chain.chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let originSendingAssetWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: originChainAsset.asset,
            runtimeProvider: originProvider
        )

        let destSendingAssetWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: destinationChainAsset.asset,
            runtimeProvider: destinationProvider
        )

        var dependencies = originSendingAssetWrapper.allOperations + destSendingAssetWrapper.allOperations

        let originUtilityAssetWrapper: CompoundOperationWrapper<AssetStorageInfo>?

        if !isSendingUtility, let asset = originChainAsset.chain.utilityAssets().first {
            let wrapper = assetStorageInfoFactory.createStorageInfoWrapper(from: asset, runtimeProvider: originProvider)

            originUtilityAssetWrapper = wrapper

            dependencies.append(contentsOf: wrapper.allOperations)
        } else {
            originUtilityAssetWrapper = nil
        }

        let destUtilityAssetWrapper: CompoundOperationWrapper<AssetStorageInfo>?

        if !isReceivingUtility, let utilityAsset = destinationChainAsset.chain.utilityAssets().first {
            let wrapper = assetStorageInfoFactory.createStorageInfoWrapper(
                from: utilityAsset,
                runtimeProvider: destinationProvider
            )

            destUtilityAssetWrapper = wrapper

            dependencies.append(contentsOf: wrapper.allOperations)
        } else {
            destUtilityAssetWrapper = nil
        }

        let mergeOperation = ClosureOperation<CrossChainAssetsStorageInfo> {
            let originSending = try originSendingAssetWrapper.targetOperation.extractNoCancellableResultData()
            let destSending = try destSendingAssetWrapper.targetOperation.extractNoCancellableResultData()
            let originUtility = try originUtilityAssetWrapper?.targetOperation.extractNoCancellableResultData()
            let destUtility = try destUtilityAssetWrapper?.targetOperation.extractNoCancellableResultData()

            return CrossChainAssetsStorageInfo(
                originSending: originSending,
                originUtility: originUtility,
                destinationSending: destSending,
                destinationUtility: destUtility
            )
        }

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    private func createSetupWrapper(
        xcmTransfers: XcmTransfers,
        originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset
    ) -> CompoundOperationWrapper<SetupResult> {
        let destinationId = XcmTransferDestinationId(
            chainAssetId: destinationChainAsset.chainAssetId,
            accountId: AccountId.zeroAccountId(of: destinationChainAsset.chain.accountIdSize)
        )

        let transferResolution = resolutionFactory.createResolutionWrapper(
            for: originChainAsset.chainAssetId,
            transferDestinationId: destinationId,
            xcmTransfers: xcmTransfers
        )

        let assetsInfoWrapper = createAssetExtractionWrapper()

        let mergeOperation = ClosureOperation<SetupResult> {
            let transferParties = try transferResolution.targetOperation.extractNoCancellableResultData()
            let assetsInfo = try assetsInfoWrapper.targetOperation.extractNoCancellableResultData()

            return (transferParties, assetsInfo)
        }

        mergeOperation.addDependency(transferResolution.targetOperation)
        mergeOperation.addDependency(assetsInfoWrapper.targetOperation)

        return assetsInfoWrapper
            .insertingHead(operations: transferResolution.allOperations)
            .insertingTail(operation: mergeOperation)
    }

    private func continueSetup() {
        feeProxy.delegate = self

        setupSendingAssetBalanceProvider()
        setupUtilityAssetBalanceProviderIfNeeded()
        setupSendingAssetPriceProviderIfNeeded()
        setupUtilityAssetPriceProviderIfNeeded()

        provideMinBalance()
        provideOriginRequiresKeepAlive()

        presenter?.didCompleteSetup(result: .success(()))
    }

    private func setupSendingAssetBalanceProvider() {
        sendingAssetProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: originChainAsset.chain.chainId,
            assetId: originChainAsset.asset.assetId
        )
    }

    private func setupUtilityAssetBalanceProviderIfNeeded() {
        let chain = originChainAsset.chain

        if !isSendingUtility, let utilityAsset = chain.utilityAssets().first {
            utilityAssetProvider = subscribeToAssetBalanceProvider(
                for: selectedAccount.accountId,
                chainId: chain.chainId,
                assetId: utilityAsset.assetId
            )
        }
    }

    private func setupSendingAssetPriceProviderIfNeeded() {
        if let priceId = originChainAsset.asset.priceId {
            sendingAssetPriceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceiveSendingAssetPrice(nil)
        }
    }

    private func setupUtilityAssetPriceProviderIfNeeded() {
        guard !isSendingUtility, let utilityAsset = originChainAsset.chain.utilityAssets().first else {
            return
        }

        if let priceId = utilityAsset.priceId {
            let options = StreamableProviderObserverOptions(
                alwaysNotifyOnRefresh: false,
                waitsInProgressSyncOnAdd: false,
                initialSize: 0,
                refreshWhenEmpty: true
            )

            utilityAssetPriceProvider = subscribeToPrice(
                for: priceId,
                currency: selectedCurrency,
                options: options
            )
        } else {
            presenter?.didReceiveUtilityAssetPrice(nil)
        }
    }

    private func provideMinBalance() {
        if let originSendingAssetInfo = assetsInfo?.originSending {
            fetchAssetExistence(
                for: originSendingAssetInfo,
                chainId: originChainAsset.chain.chainId,
                asset: originChainAsset.asset
            ) { [weak self] result in
                switch result {
                case let .success(existence):
                    self?.presenter?.didReceiveOriginSendingMinBalance(existence.minBalance)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        if
            let originUtilityAssetInfo = assetsInfo?.originUtility,
            let utilityAsset = originChainAsset.chain.utilityAsset() {
            fetchAssetExistence(
                for: originUtilityAssetInfo,
                chainId: originChainAsset.chain.chainId,
                asset: utilityAsset
            ) { [weak self] result in
                switch result {
                case let .success(existence):
                    self?.presenter?.didReceiveOriginUtilityMinBalance(existence.minBalance)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        if let destSendingAssetInfo = assetsInfo?.destinationSending {
            let destinationChainId = destinationChainAsset.chain.chainId

            fetchAssetExistence(
                for: destSendingAssetInfo,
                chainId: destinationChainId,
                asset: destinationChainAsset.asset
            ) { [weak self] result in
                switch result {
                case let .success(existence):
                    self?.presenter?.didReceiveDestSendingExistence(existence)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        if
            let destUtilityAssetInfo = assetsInfo?.destinationUtility,
            let utilityAsset = destinationChainAsset.chain.utilityAsset() {
            let destinationChainId = destinationChainAsset.chain.chainId

            fetchAssetExistence(
                for: destUtilityAssetInfo,
                chainId: destinationChainId,
                asset: utilityAsset
            ) { [weak self] result in
                switch result {
                case let .success(existence):
                    self?.presenter?.didReceiveDestUtilityMinBalance(existence.minBalance)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        }
    }

    private func provideOriginRequiresKeepAlive() {
        guard let transferParties else {
            return
        }

        let features = XcmTransferFeaturesFactory().createFeatures(for: transferParties.metadata)

        let keepAlive = fungibilityPreservationProvider.requiresPreservationForCrosschain(
            assetIn: originChainAsset.chainAssetId,
            features: features
        )

        presenter?.didReceiveRequiresOriginKeepAlive(keepAlive)
    }

    private func subscribeUtilityRecepientAssetBalance() {
        let chain = destinationChainAsset.chain

        guard
            let utilityAssetInfo = assetsInfo?.destinationUtility,
            let recepientAccountId = recepientAccountId,
            let utilityAsset = chain.utilityAssets().first else {
            return
        }

        utilityAssetSubscriptionId = walletRemoteWrapper.subscribe(
            using: utilityAssetInfo,
            accountId: recepientAccountId,
            chainAsset: ChainAsset(chain: chain, asset: utilityAsset),
            completion: nil
        )

        recepientUtilityAssetProvider = subscribeToAssetBalanceProvider(
            for: recepientAccountId,
            chainId: chain.chainId,
            assetId: utilityAsset.assetId
        )
    }

    private func subscribeSendingRecepientAssetBalance() {
        guard
            let destinationAssetInfo = assetsInfo?.destinationSending,
            let recepientAccountId = recepientAccountId else {
            return
        }

        sendingAssetSubscriptionId = walletRemoteWrapper.subscribe(
            using: destinationAssetInfo,
            accountId: recepientAccountId,
            chainAsset: destinationChainAsset,
            completion: nil
        )

        recepientSendingAssetProvider = subscribeToAssetBalanceProvider(
            for: recepientAccountId,
            chainId: destinationChainAsset.chain.chainId,
            assetId: destinationChainAsset.asset.assetId
        )
    }

    private func clearSendingAssetRemoteRecepientSubscription() {
        guard
            let destinationAssetInfo = assetsInfo?.destinationSending,
            let recepientAccountId = recepientAccountId,
            let sendingAssetSubscriptionId = sendingAssetSubscriptionId else {
            return
        }

        walletRemoteWrapper.unsubscribe(
            from: sendingAssetSubscriptionId,
            assetStorageInfo: destinationAssetInfo,
            accountId: recepientAccountId,
            chainAssetId: destinationChainAsset.chainAssetId,
            completion: nil
        )

        self.sendingAssetSubscriptionId = nil
    }

    private func clearSendingAssetLocaleRecepientSubscription() {
        recepientSendingAssetProvider?.removeObserver(self)
        recepientSendingAssetProvider = nil
    }

    private func clearUtilityAssetRemoteRecepientSubscriptions() {
        guard
            let utilityAssetInfo = assetsInfo?.destinationUtility,
            let recepientAccountId = recepientAccountId,
            let utilityAssetSubscriptionId = utilityAssetSubscriptionId,
            let utilityAsset = destinationChainAsset.chain.utilityAssets().first else {
            return
        }

        let chain = destinationChainAsset.chain

        walletRemoteWrapper.unsubscribe(
            from: utilityAssetSubscriptionId,
            assetStorageInfo: utilityAssetInfo,
            accountId: recepientAccountId,
            chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: utilityAsset.assetId),
            completion: nil
        )

        self.utilityAssetSubscriptionId = nil
    }

    private func clearUtilityAssetLocaleRecepientSubscriptions() {
        recepientUtilityAssetProvider?.removeObserver(self)
        recepientUtilityAssetProvider = nil
    }
}

extension CrossChainTransferInteractor {
    func setup() {
        guard !setupCallStore.hasCall else {
            return
        }

        let setupWrapper = createSetupWrapper(
            xcmTransfers: xcmTransfers,
            originChainAsset: originChainAsset,
            destinationChainAsset: destinationChainAsset
        )

        executeCancellable(
            wrapper: setupWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: setupCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(model):
                let (transferParties, assetsInfo) = model
                self?.transferParties = transferParties
                self?.assetsInfo = assetsInfo

                self?.continueSetup()
            case let .failure(error):
                self?.presenter?.didCompleteSetup(result: .failure(error))
            }
        }
    }

    func estimateOriginFee(for amount: BigUInt, recepient: AccountId?) {
        guard let transferParties = transferParties else {
            return
        }

        let recepientAccountId = recepient ?? AccountId.zeroAccountId(of: destinationChainAsset.chain.accountIdSize)

        let identifier = "origin" + "-" + String(amount) + "-" + recepientAccountId.toHex()

        let destination = transferParties.destination.replacing(accountId: recepientAccountId)
        let unweightedRequest = XcmUnweightedTransferRequest(
            origin: transferParties.origin,
            destination: destination,
            reserve: transferParties.reserve,
            metadata: transferParties.metadata,
            amount: amount
        )

        let transferRequest = XcmTransferRequest(unweighted: unweightedRequest)

        feeProxy.estimateOriginFee(
            using: extrinsicService,
            xcmTransferRequest: transferRequest,
            reuseIdentifier: identifier
        )
    }

    func estimateCrossChainFee(for amount: BigUInt, recepient: AccountId?) {
        guard let transferParties = transferParties else {
            return
        }

        let recepientAccountId = recepient ?? AccountId.zeroAccountId(of: destinationChainAsset.chain.accountIdSize)

        let identifier = "crosschain" + "-" + String(amount) + "-" + recepientAccountId.toHex()

        let destination = transferParties.destination.replacing(accountId: recepientAccountId)
        let request = XcmUnweightedTransferRequest(
            origin: transferParties.origin,
            destination: destination,
            reserve: transferParties.reserve,
            metadata: transferParties.metadata,
            amount: amount
        )

        feeProxy.estimateCrossChainFee(
            using: extrinsicService,
            xcmTransferRequest: request,
            reuseIdentifier: identifier
        )
    }

    func change(recepient: AccountId?) {
        guard recepientAccountId != recepient else {
            return
        }

        clearSendingAssetRemoteRecepientSubscription()
        clearUtilityAssetRemoteRecepientSubscriptions()
        clearSendingAssetLocaleRecepientSubscription()
        clearUtilityAssetLocaleRecepientSubscriptions()

        recepientAccountId = recepient

        subscribeSendingRecepientAssetBalance()
        subscribeUtilityRecepientAssetBalance()
    }
}

extension CrossChainTransferInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        switch result {
        case let .success(optBalance):
            let balance = optBalance ??
                AssetBalance.createZero(
                    for: ChainAssetId(chainId: chainId, assetId: assetId),
                    accountId: accountId
                )

            let chainAssetId = ChainAssetId(chainId: chainId, assetId: assetId)

            if accountId == selectedAccount.accountId {
                if originChainAsset.chainAssetId == chainAssetId {
                    presenter?.didReceiveSendingAssetSenderBalance(balance)
                } else if
                    originChainAsset.chain.chainId == chainId,
                    originChainAsset.chain.utilityAssets().first?.assetId == assetId {
                    presenter?.didReceiveUtilityAssetSenderBalance(balance)
                }
            }

            if accountId == recepientAccountId {
                if destinationChainAsset.chainAssetId == chainAssetId {
                    presenter?.didReceiveSendingAssetRecepientBalance(balance)
                } else if
                    destinationChainAsset.chain.chainId == chainId,
                    destinationChainAsset.chain.utilityAssets().first?.assetId == assetId {
                    presenter?.didReceiveUtilityAssetRecepientBalance(balance)
                }
            }
        case .failure:
            presenter?.didReceiveError(CommonError.databaseSubscription)
        }
    }
}

extension CrossChainTransferInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            if originChainAsset.asset.priceId == priceId {
                presenter?.didReceiveSendingAssetPrice(priceData)
            } else if originChainAsset.chain.utilityAssets().first?.priceId == priceId {
                presenter?.didReceiveUtilityAssetPrice(priceData)
            }
        case .failure:
            presenter?.didReceiveError(CommonError.databaseSubscription)
        }
    }
}

extension CrossChainTransferInteractor: XcmExtrinsicFeeProxyDelegate {
    func didReceiveOriginFee(
        result: XcmTransferOriginFeeResult,
        for _: TransactionFeeId
    ) {
        switch result {
        case let .success(feeWithWeight):
            presenter?.didReceiveOriginFee(result: .success(feeWithWeight))
        case let .failure(error):
            presenter?.didReceiveOriginFee(result: .failure(error))
        }
    }

    func didReceiveCrossChainFee(result: XcmTransferCrosschainFeeResult, for _: TransactionFeeId) {
        presenter?.didReceiveCrossChainFee(result: result)
    }
}

extension CrossChainTransferInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        setupUtilityAssetPriceProviderIfNeeded()
    }
}
