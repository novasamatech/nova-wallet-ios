import Foundation
import RobinHood
import BigInt
import SubstrateSdk

private struct CrossChainAssetsStorageInfo {
    let originSending: AssetStorageInfo
    let originUtility: AssetStorageInfo?
    let destinationSending: AssetStorageInfo
    let destinationUtility: AssetStorageInfo?
}

class CrossChainTransferInteractor: RuntimeConstantFetching {
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
    let operationQueue: OperationQueue

    private lazy var callFactory = SubstrateCallFactory()
    private lazy var assetStorageInfoFactory = AssetStorageInfoOperationFactory()

    private var sendingAssetProvider: StreamableProvider<AssetBalance>?
    private var utilityAssetProvider: StreamableProvider<AssetBalance>?
    private var sendingAssetPriceProvider: AnySingleValueProvider<PriceData>?
    private var utilityAssetPriceProvider: AnySingleValueProvider<PriceData>?

    private var recepientAccountId: AccountId?

    private var setupCall: CancellableCall?

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
        walletRemoteWrapper: WalletRemoteSubscriptionWrapperProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
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
        self.walletRemoteWrapper = walletRemoteWrapper
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.substrateStorageFacade = substrateStorageFacade
        self.operationQueue = operationQueue
    }

    deinit {
        cancelSetupCall()

        clearSendingAssetRemoteRecepientSubscription()
        clearUtilityAssetRemoteRecepientSubscriptions()
    }

    private func fetchMinBalance(
        for assetStorageInfo: AssetStorageInfo,
        chainId: ChainModel.Id,
        completionClosure: @escaping (Result<BigUInt, Error>) -> Void
    ) {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            completionClosure(.failure(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        switch assetStorageInfo {
        case .native:
            fetchConstant(
                for: .existentialDeposit,
                runtimeCodingService: runtimeService,
                operationManager: OperationManager(operationQueue: operationQueue),
                closure: completionClosure
            )
        case let .statemine(extras):
            let wrapper = assetStorageInfoFactory.createAssetsMinBalanceOperation(
                for: extras,
                chainId: chainId,
                storage: chainStorage,
                runtimeService: runtimeService
            )

            wrapper.targetOperation.completionBlock = {
                DispatchQueue.main.async {
                    do {
                        let minBalance = try wrapper.targetOperation.extractNoCancellableResultData()
                        completionClosure(.success(minBalance))
                    } catch {
                        completionClosure(.failure(error))
                    }
                }
            }

            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        case let .orml(_, _, _, existentialDeposit):
            completionClosure(.success(existentialDeposit))
        }
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

    private func createSetupWrapper() -> CompoundOperationWrapper<(XcmTransferParties, CrossChainAssetsStorageInfo)> {
        let chain = destinationChainAsset.chain
        let destinationId = XcmTransferDestinationId(
            chainId: chain.chainId,
            accountId: AccountId.dummyAccountId(of: chain.accountIdSize)
        )

        let transferResolution = resolutionFactory.createResolutionWrapper(
            for: originChainAsset.chainAssetId,
            transferDestinationId: destinationId,
            xcmTransfers: xcmTransfers
        )

        let assetsInfoWrapper = createAssetExtractionWrapper()

        let mergeOperation = ClosureOperation<(XcmTransferParties, CrossChainAssetsStorageInfo)> {
            let transferParties = try transferResolution.targetOperation.extractNoCancellableResultData()
            let assetsInfo = try assetsInfoWrapper.targetOperation.extractNoCancellableResultData()

            return (transferParties, assetsInfo)
        }

        mergeOperation.addDependency(transferResolution.targetOperation)
        mergeOperation.addDependency(assetsInfoWrapper.targetOperation)

        let dependencies = transferResolution.allOperations + assetsInfoWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    private func continueSetup() {
        feeProxy.delegate = self

        setupSendingAssetBalanceProvider()
        setupUtilityAssetBalanceProviderIfNeeded()
        setupSendingAssetPriceProviderIfNeeded()
        setupUtilityAssetPriceProviderIfNeeded()

        provideMinBalance()

        presenter?.didCompleteSetup()
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
            let options = DataProviderObserverOptions(
                alwaysNotifyOnRefresh: false,
                waitsInProgressSyncOnAdd: false
            )

            sendingAssetPriceProvider = subscribeToPrice(for: priceId, options: options)
        } else {
            presenter?.didReceiveSendingAssetPrice(nil)
        }
    }

    private func setupUtilityAssetPriceProviderIfNeeded() {
        guard !isSendingUtility, let utilityAsset = originChainAsset.chain.utilityAssets().first else {
            return
        }

        if let priceId = utilityAsset.priceId {
            let options = DataProviderObserverOptions(
                alwaysNotifyOnRefresh: false,
                waitsInProgressSyncOnAdd: false
            )

            utilityAssetPriceProvider = subscribeToPrice(for: priceId, options: options)
        } else {
            presenter?.didReceiveUtilityAssetPrice(nil)
        }
    }

    private func provideMinBalance() {
        let originChainId = originChainAsset.chain.chainId

        if let originSendingAssetInfo = assetsInfo?.originSending {
            fetchMinBalance(for: originSendingAssetInfo, chainId: originChainId) { [weak self] result in
                switch result {
                case let .success(minBalance):
                    self?.presenter?.didReceiveOriginSendingMinBalance(minBalance)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        if let originUtilityAssetInfo = assetsInfo?.originUtility {
            fetchMinBalance(for: originUtilityAssetInfo, chainId: originChainId) { [weak self] result in
                switch result {
                case let .success(minBalance):
                    self?.presenter?.didReceiveOriginUtilityMinBalance(minBalance)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        if let destSendingAssetInfo = assetsInfo?.destinationSending {
            let destinationChainId = destinationChainAsset.chain.chainId

            fetchMinBalance(for: destSendingAssetInfo, chainId: destinationChainId) { [weak self] result in
                switch result {
                case let .success(minBalance):
                    self?.presenter?.didReceiveDestSendingMinBalance(minBalance)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        if let destUtilityAssetInfo = assetsInfo?.destinationUtility {
            let destinationChainId = destinationChainAsset.chain.chainId

            fetchMinBalance(for: destUtilityAssetInfo, chainId: destinationChainId) { [weak self] result in
                switch result {
                case let .success(minBalance):
                    self?.presenter?.didReceiveDestUtilityMinBalance(minBalance)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        }
    }

    private func cancelSetupCall() {
        let cancellingCall = setupCall
        setupCall = nil
        cancellingCall?.cancel()
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
        let setupWrapper = createSetupWrapper()

        setupWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.setupCall === setupWrapper else {
                    return
                }

                self?.setupCall = nil

                do {
                    let (transferParties, assetsInfo) = try setupWrapper.targetOperation
                        .extractNoCancellableResultData()

                    self?.transferParties = transferParties
                    self?.assetsInfo = assetsInfo

                    self?.continueSetup()
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        setupCall = setupWrapper

        operationQueue.addOperations(setupWrapper.allOperations, waitUntilFinished: false)
    }

    func estimateOriginFee(for amount: BigUInt, recepient: AccountAddress?, weightLimit: BigUInt?) {
        do {
            guard let transferParties = transferParties else {
                throw CommonError.dataCorruption
            }

            let recepientAccountId: AccountId

            if let recepient = recepient {
                recepientAccountId = try recepient.toAccountId()
            } else {
                recepientAccountId = AccountId.dummyAccountId(of: destinationChainAsset.chain.accountIdSize)
            }

            let maxWeight = weightLimit ?? 0
            let identifier = "origin" + "-" + String(amount) + "-" + recepientAccountId.toHex() +
                "-" + String(maxWeight)

            let destination = transferParties.destination.replacing(accountId: recepientAccountId)
            let unweightedRequest = XcmUnweightedTransferRequest(
                origin: originChainAsset,
                destination: destination,
                reserve: transferParties.reserve,
                amount: amount
            )

            let transferRequest = XcmTransferRequest(unweighted: unweightedRequest, maxWeight: weightLimit ?? 0)

            feeProxy.estimateOriginFee(
                using: extrinsicService,
                xcmTransferRequest: transferRequest,
                xcmTransfers: xcmTransfers,
                reuseIdentifier: identifier
            )
        } catch {
            presenter?.didReceiveError(CommonError.dataCorruption)
        }
    }

    func estimateCrossChainFee(for amount: BigUInt, recepient: AccountAddress?) {
        do {
            guard let transferParties = transferParties else {
                throw CommonError.dataCorruption
            }

            let recepientAccountId: AccountId

            if let recepient = recepient {
                recepientAccountId = try recepient.toAccountId()
            } else {
                recepientAccountId = AccountId.dummyAccountId(of: destinationChainAsset.chain.accountIdSize)
            }

            let identifier = "crosschain" + "-" + String(amount) + "-" + recepientAccountId.toHex()

            let destination = transferParties.destination.replacing(accountId: recepientAccountId)
            let request = XcmUnweightedTransferRequest(
                origin: originChainAsset,
                destination: destination,
                reserve: transferParties.reserve,
                amount: amount
            )

            feeProxy.estimateCrossChainFee(
                using: extrinsicService,
                xcmTransferRequest: request,
                xcmTransfers: xcmTransfers,
                reuseIdentifier: identifier
            )
        } catch {
            presenter?.didReceiveError(CommonError.dataCorruption)
        }
    }

    func change(recepient: AccountAddress?) {
        guard
            let newRecepientAccountId = try? recepient?.toAccountId(),
            newRecepientAccountId != recepientAccountId else {
            return
        }

        clearSendingAssetRemoteRecepientSubscription()
        clearUtilityAssetRemoteRecepientSubscriptions()
        clearSendingAssetLocaleRecepientSubscription()
        clearUtilityAssetLocaleRecepientSubscriptions()

        recepientAccountId = newRecepientAccountId

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

            if accountId == selectedAccount.accountId {
                if originChainAsset.asset.assetId == assetId {
                    presenter?.didReceiveSendingAssetSenderBalance(balance)
                } else if originChainAsset.chain.utilityAssets().first?.assetId == assetId {
                    presenter?.didReceiveUtilityAssetSenderBalance(balance)
                }
            } else if accountId == recepientAccountId {
                if destinationChainAsset.asset.assetId == assetId {
                    presenter?.didReceiveSendingAssetRecepientBalance(balance)
                } else if destinationChainAsset.chain.utilityAssets().first?.assetId == assetId {
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
        result: XcmTrasferFeeResult,
        for _: ExtrinsicFeeId
    ) {
        switch result {
        case let .success(feeWithWeight):
            presenter?.didReceiveOriginFee(result: .success(feeWithWeight.fee))
        case let .failure(error):
            presenter?.didReceiveOriginFee(result: .failure(error))
        }
    }

    func didReceiveCrossChainFee(result: XcmTrasferFeeResult, for _: ExtrinsicFeeId) {
        presenter?.didReceiveCrossChainFee(result: result)
    }
}
