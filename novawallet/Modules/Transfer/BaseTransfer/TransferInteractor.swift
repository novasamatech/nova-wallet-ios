import Foundation
import RobinHood
import BigInt
import SubstrateSdk

class TransferInteractor: RuntimeConstantFetching {
    weak var presenter: TransferSetupInteractorOutputProtocol?

    let selectedAccount: ChainAccountResponse
    let chain: ChainModel
    let asset: AssetModel
    let runtimeService: RuntimeCodingServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let walletRemoteWrapper: WalletRemoteSubscriptionWrapperProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let substrateStorageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue

    private lazy var callFactory = SubstrateCallFactory()

    private var sendingAssetProvider: StreamableProvider<AssetBalance>?
    private var utilityAssetProvider: StreamableProvider<AssetBalance>?
    private var sendingAssetPriceProvider: AnySingleValueProvider<PriceData>?
    private var utilityAssetPriceProvider: AnySingleValueProvider<PriceData>?
    private var codingFactoryOperation: CancellableCall?
    private var recepientAccountId: AccountId?

    private var sendingAssetInfo: AssetStorageInfo?
    private var utilityAssetInfo: AssetStorageInfo?

    private var sendingAssetSubscriptionId: UUID?
    private var utilityAssetSubscriptionId: UUID?

    private var recepientSendingAssetProvider: StreamableProvider<AssetBalance>?
    private var recepientUtilityAssetProvider: StreamableProvider<AssetBalance>?

    var isUtilityTransfer: Bool { chain.utilityAssets().first?.assetId == asset.assetId }

    private lazy var chainStorage: AnyDataProviderRepository<ChainStorageItem> = {
        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            substrateStorageFacade.createRepository()
        return AnyDataProviderRepository(storage)
    }()

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        walletRemoteWrapper: WalletRemoteSubscriptionWrapperProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.asset = asset
        self.runtimeService = runtimeService
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.walletRemoteWrapper = walletRemoteWrapper
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.substrateStorageFacade = substrateStorageFacade
        self.operationQueue = operationQueue
    }

    deinit {
        cancelCodingFactoryOperation()

        clearSendingAssetRemoteRecepientSubscription()
        clearUtilityAssetRemoteRecepientSubscriptions()
    }

    private func fetchStatemineMinBalance(
        for extras: StatemineAssetExtras,
        completionClosure: @escaping (Result<BigUInt, Error>) -> Void
    ) {
        do {
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                .assetsDetails,
                encodableElement: extras.assetId,
                chainId: chain.chainId
            )

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let localRequestFactory = LocalStorageRequestFactory()

            let fetchWrapper: CompoundOperationWrapper<LocalStorageResponse<AssetDetails>> =
                localRequestFactory.queryItems(
                    repository: chainStorage,
                    key: { localKey },
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    params: StorageRequestParams(path: .assetsDetails, shouldFallback: false)
                )

            fetchWrapper.addDependency(operations: [codingFactoryOperation])

            let mappingOperation = ClosureOperation<BigUInt> {
                let details = try fetchWrapper.targetOperation.extractNoCancellableResultData()
                return details.value?.minBalance ?? 0
            }

            let dependencies = [codingFactoryOperation] + fetchWrapper.allOperations

            dependencies.forEach { mappingOperation.addDependency($0) }

            mappingOperation.completionBlock = {
                DispatchQueue.main.async {
                    do {
                        let minBalance = try mappingOperation.extractNoCancellableResultData()
                        completionClosure(.success(minBalance))
                    } catch {
                        completionClosure(.failure(error))
                    }
                }
            }

            operationQueue.addOperations(dependencies + [mappingOperation], waitUntilFinished: false)
        } catch {
            completionClosure(.failure(error))
        }
    }

    private func fetchMinBalance(
        for assetStorageInfo: AssetStorageInfo,
        completionClosure: @escaping (Result<BigUInt, Error>) -> Void
    ) {
        switch assetStorageInfo {
        case .native:
            fetchConstant(
                for: .existentialDeposit,
                runtimeCodingService: runtimeService,
                operationManager: OperationManager(operationQueue: operationQueue),
                closure: completionClosure
            )
        case let .statemine(extras):
            fetchStatemineMinBalance(for: extras, completionClosure: completionClosure)
        case let .orml(_, _, _, existentialDeposit):
            completionClosure(.success(existentialDeposit))
        }
    }

    private func extractAssetStorageInfo() {
        guard codingFactoryOperation == nil else {
            return
        }

        let operation = runtimeService.fetchCoderFactoryOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    guard !operation.isCancelled else {
                        return
                    }

                    self?.codingFactoryOperation = nil

                    let codingFactory = try operation.extractNoCancellableResultData()
                    try self?.extractAssetStorageInfo(using: codingFactory)

                    self?.continueSetup()
                } catch {
                    self?.presenter?.didReceiveError(CommonError.dataCorruption)
                }
            }
        }

        codingFactoryOperation = operation

        operationQueue.addOperation(operation)
    }

    private func extractAssetStorageInfo(using codingFactory: RuntimeCoderFactoryProtocol) throws {
        sendingAssetInfo = try AssetStorageInfo.extract(
            from: asset,
            codingFactory: codingFactory
        )

        if !isUtilityTransfer, let utilityAsset = chain.utilityAssets().first {
            utilityAssetInfo = try AssetStorageInfo.extract(
                from: utilityAsset,
                codingFactory: codingFactory
            )
        }
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
            chainId: chain.chainId,
            assetId: asset.assetId
        )
    }

    private func setupUtilityAssetBalanceProviderIfNeeded() {
        if !isUtilityTransfer, let utilityAsset = chain.utilityAssets().first {
            utilityAssetProvider = subscribeToAssetBalanceProvider(
                for: selectedAccount.accountId,
                chainId: chain.chainId,
                assetId: utilityAsset.assetId
            )
        }
    }

    private func setupSendingAssetPriceProviderIfNeeded() {
        if let priceId = asset.priceId {
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
        guard !isUtilityTransfer, let utilityAsset = chain.utilityAssets().first else {
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
        if let sendingAssetInfo = sendingAssetInfo {
            fetchMinBalance(for: sendingAssetInfo) { [weak self] result in
                switch result {
                case let .success(minBalance):
                    self?.presenter?.didReceiveSendingAssetMinBalance(minBalance)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        if let utilityAssetInfo = utilityAssetInfo {
            fetchMinBalance(for: utilityAssetInfo) { [weak self] result in
                switch result {
                case let .success(minBalance):
                    self?.presenter?.didReceiveUtilityAssetMinBalance(minBalance)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        }
    }

    func addingTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: BigUInt,
        recepient: AccountId
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        guard let sendingAssetInfo = sendingAssetInfo else {
            return (builder, nil)
        }

        switch sendingAssetInfo {
        case let .orml(currencyId, _, module, _):
            let call = callFactory.ormlTransfer(
                in: module,
                currencyId: currencyId,
                receiverId: recepient,
                amount: amount
            )

            let newBuilder = try builder.adding(call: call)
            return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
        case let .statemine(extras):
            let call = callFactory.assetsTransfer(
                to: recepient,
                assetId: extras.assetId,
                amount: amount
            )

            let newBuilder = try builder.adding(call: call)
            return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
        case .native:
            let call = callFactory.nativeTransfer(to: recepient, amount: amount)
            let newBuilder = try builder.adding(call: call)
            return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
        }
    }

    private func cancelCodingFactoryOperation() {
        let cancellingOperation = codingFactoryOperation
        codingFactoryOperation = nil
        cancellingOperation?.cancel()
    }

    private func subscribeUtilityRecepientAssetBalance() {
        guard
            let utilityAssetInfo = utilityAssetInfo,
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
            let sendingAssetInfo = sendingAssetInfo,
            let recepientAccountId = recepientAccountId else {
            return
        }

        sendingAssetSubscriptionId = walletRemoteWrapper.subscribe(
            using: sendingAssetInfo,
            accountId: recepientAccountId,
            chainAsset: ChainAsset(chain: chain, asset: asset),
            completion: nil
        )

        recepientSendingAssetProvider = subscribeToAssetBalanceProvider(
            for: recepientAccountId,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
    }

    private func clearSendingAssetRemoteRecepientSubscription() {
        guard
            let sendingAssetInfo = sendingAssetInfo,
            let recepientAccountId = recepientAccountId,
            let sendingAssetSubscriptionId = sendingAssetSubscriptionId else {
            return
        }

        walletRemoteWrapper.unsubscribe(
            from: sendingAssetSubscriptionId,
            assetStorageInfo: sendingAssetInfo,
            accountId: recepientAccountId,
            chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
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
            let utilityAssetInfo = utilityAssetInfo,
            let recepientAccountId = recepientAccountId,
            let utilityAssetSubscriptionId = utilityAssetSubscriptionId else {
            return
        }

        walletRemoteWrapper.unsubscribe(
            from: utilityAssetSubscriptionId,
            assetStorageInfo: utilityAssetInfo,
            accountId: recepientAccountId,
            chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: asset.assetId),
            completion: nil
        )

        self.utilityAssetSubscriptionId = nil
    }

    private func clearUtilityAssetLocaleRecepientSubscriptions() {
        recepientUtilityAssetProvider?.removeObserver(self)
        recepientUtilityAssetProvider = nil
    }
}

extension TransferInteractor {
    func setup() {
        extractAssetStorageInfo()
    }

    func estimateFee(for amount: BigUInt, recepient: AccountAddress?) {
        do {
            cancelCodingFactoryOperation()

            let recepientAccountId: AccountId

            if let recepient = recepient {
                recepientAccountId = try recepient.toAccountId()
            } else {
                recepientAccountId = selectedAccount.accountId
            }

            let identifier = String(amount) + "-" + recepientAccountId.toHex()

            feeProxy.estimateFee(
                using: extrinsicService,
                reuseIdentifier: identifier
            ) { [weak self] builder in
                let (newBuilder, _) = try self?.addingTransferCommand(
                    to: builder,
                    amount: amount,
                    recepient: recepientAccountId
                ) ?? (builder, nil)

                return newBuilder
            }
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

extension TransferInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
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
                if asset.assetId == assetId {
                    presenter?.didReceiveSendingAssetSenderBalance(balance)
                } else if chain.utilityAssets().first?.assetId == assetId {
                    presenter?.didReceiveUtilityAssetSenderBalance(balance)
                }
            } else if accountId == recepientAccountId {
                if asset.assetId == assetId {
                    presenter?.didReceiveSendingAssetRecepientBalance(balance)
                } else if chain.utilityAssets().first?.assetId == assetId {
                    presenter?.didReceiveUtilityAssetRecepientBalance(balance)
                }
            }
        case .failure:
            presenter?.didReceiveError(CommonError.databaseSubscription)
        }
    }
}

extension TransferInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            if asset.priceId == priceId {
                presenter?.didReceiveSendingAssetPrice(priceData)
            } else if chain.utilityAssets().first?.priceId == priceId {
                presenter?.didReceiveUtilityAssetPrice(priceData)
            }
        case .failure:
            presenter?.didReceiveError(CommonError.databaseSubscription)
        }
    }
}

extension TransferInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(
        result: Result<RuntimeDispatchInfo, Error>,
        for _: ExtrinsicFeeId
    ) {
        switch result {
        case let .success(info):
            let fee = BigUInt(info.fee) ?? 0
            presenter?.didReceiveFee(result: .success(fee))
        case let .failure(error):
            presenter?.didReceiveFee(result: .failure(error))
        }
    }
}
