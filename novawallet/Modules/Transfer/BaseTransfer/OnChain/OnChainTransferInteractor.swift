import Foundation
import Operation_iOS
import BigInt
import SubstrateSdk

class OnChainTransferInteractor: OnChainTransferBaseInteractor, RuntimeConstantFetching {
    let runtimeService: RuntimeCodingServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let walletRemoteWrapper: WalletRemoteSubscriptionWrapperProtocol
    let substrateStorageFacade: StorageFacadeProtocol
    let transferAggregationWrapperFactory: AssetTransferAggregationFactoryProtocol

    private lazy var callFactory = SubstrateCallFactory()
    private lazy var assetStorageInfoFactory = AssetStorageInfoOperationFactory()

    private var setupCall: CancellableCall?

    private var recepientAccountId: AccountId?

    private var sendingAssetInfo: AssetStorageInfo?
    private var utilityAssetInfo: AssetStorageInfo?

    private(set) var feeAsset: ChainAsset?

    private var sendingAssetSubscriptionId: UUID?
    private var utilityAssetSubscriptionId: UUID?

    private var recepientSendingAssetProvider: StreamableProvider<AssetBalance>?
    private var recepientUtilityAssetProvider: StreamableProvider<AssetBalance>?

    private lazy var chainStorage: AnyDataProviderRepository<ChainStorageItem> = {
        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            substrateStorageFacade.createRepository()
        return AnyDataProviderRepository(storage)
    }()

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        feeAsset: ChainAsset?,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        walletRemoteWrapper: WalletRemoteSubscriptionWrapperProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        transferAggregationWrapperFactory: AssetTransferAggregationFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.runtimeService = runtimeService
        self.feeProxy = feeProxy
        self.feeAsset = feeAsset
        self.extrinsicService = extrinsicService
        self.walletRemoteWrapper = walletRemoteWrapper
        self.substrateStorageFacade = substrateStorageFacade
        self.transferAggregationWrapperFactory = transferAggregationWrapperFactory

        super.init(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            operationQueue: operationQueue
        )

        self.currencyManager = currencyManager
    }

    deinit {
        cancelSetupCall()

        clearSendingAssetRemoteRecepientSubscription()
        clearUtilityAssetRemoteRecepientSubscriptions()
    }

    override func handleAssetBalance(
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

    func addingTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recepient: AccountId
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        guard let sendingAssetInfo = sendingAssetInfo else {
            return (builder, nil)
        }

        switch sendingAssetInfo {
        case let .orml(info), let .ormlHydrationEvm(info):
            return try addingOrmlTransferCommand(
                to: builder,
                amount: amount,
                recepient: recepient,
                tokenStorageInfo: info
            )
        case let .statemine(info):
            return try addingAssetsTransferCommand(
                to: builder,
                amount: amount,
                recepient: recepient,
                info: info
            )
        case let .native(info):
            return try addingNativeTransferCommand(
                to: builder,
                amount: amount,
                recepient: recepient,
                info: info
            )
        case let .equilibrium(extras):
            return try addingEquilibriumTransferCommand(
                to: builder,
                amount: amount,
                recepient: recepient,
                extras: extras
            )
        case .erc20, .evmNative:
            // we have a separate flow for evm
            return (builder, nil)
        }
    }
    
    func estimateFee(for amount: OnChainTransferAmount<BigUInt>, recepient: AccountId?) {
        let recepientAccountId = recepient ?? AccountId.zeroAccountId(of: chain.accountIdSize)

        let identifier = String(amount.value) + "-" + recepientAccountId.toHex() + "-" + amount.name

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: identifier,
            payingIn: feeAsset?.chainAssetId
        ) { [weak self] builder in
            let (newBuilder, _) = try self?.addingTransferCommand(
                to: builder,
                amount: amount,
                recepient: recepientAccountId
            ) ?? (builder, nil)

            return newBuilder
        }
    }
    
    func processFee(
        result: Result<ExtrinsicFeeProtocol, Error>,
        for transactionFeeId: TransactionFeeId
    ) {
        switch result {
        case let .success(info):
            let feeModel = FeeOutputModel(value: info, validationProvider: nil)
            presenter?.didReceiveFee(result: .success(feeModel))
        case let .failure(error):
            presenter?.didReceiveFee(result: .failure(error))
        }
    }
}

private extension OnChainTransferInteractor {
    func addingOrmlTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recepient: AccountId,
        tokenStorageInfo: OrmlTokenStorageInfo
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        switch amount {
        case let .concrete(value):
            return try addingOrmlTransferValueCommand(
                to: builder,
                recepient: recepient,
                tokenStorageInfo: tokenStorageInfo,
                value: value
            )
        case let .all(value):
            if tokenStorageInfo.canTransferAll {
                return try addingOrmlTransferAllCommand(
                    to: builder,
                    recepient: recepient,
                    tokenStorageInfo: tokenStorageInfo
                )
            } else {
                return try addingOrmlTransferValueCommand(
                    to: builder,
                    recepient: recepient,
                    tokenStorageInfo: tokenStorageInfo,
                    value: value
                )
            }
        }
    }

    func addingOrmlTransferValueCommand(
        to builder: ExtrinsicBuilderProtocol,
        recepient: AccountId,
        tokenStorageInfo: OrmlTokenStorageInfo,
        value: BigUInt
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        let call = callFactory.ormlTransfer(
            in: tokenStorageInfo.module,
            currencyId: tokenStorageInfo.currencyId,
            receiverId: recepient,
            amount: value
        )

        let newBuilder = try builder.adding(call: call)
        return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
    }

    func addingOrmlTransferAllCommand(
        to builder: ExtrinsicBuilderProtocol,
        recepient: AccountId,
        tokenStorageInfo: OrmlTokenStorageInfo
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        let call = callFactory.ormlTransferAll(
            in: tokenStorageInfo.module,
            currencyId: tokenStorageInfo.currencyId,
            receiverId: recepient
        )
        let newBuilder = try builder.adding(call: call)
        return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
    }

    func addingNativeTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recepient: AccountId,
        info: NativeTokenStorageInfo
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        switch amount {
        case let .concrete(value):
            return try addingNativeTransferValueCommand(
                to: builder,
                recepient: recepient,
                value: value,
                callPath: info.transferCallPath
            )
        case let .all(value):
            if info.canTransferAll {
                return try addingNativeTransferAllCommand(to: builder, recepient: recepient)
            } else {
                return try addingNativeTransferValueCommand(
                    to: builder,
                    recepient: recepient,
                    value: value,
                    callPath: info.transferCallPath
                )
            }
        }
    }

    func addingNativeTransferValueCommand(
        to builder: ExtrinsicBuilderProtocol,
        recepient: AccountId,
        value: BigUInt,
        callPath: CallCodingPath
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        let call = callFactory.nativeTransfer(to: recepient, amount: value, callPath: callPath)
        let newBuilder = try builder.adding(call: call)
        return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
    }

    func addingNativeTransferAllCommand(
        to builder: ExtrinsicBuilderProtocol,
        recepient: AccountId
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        let call = callFactory.nativeTransferAll(to: recepient)
        let newBuilder = try builder.adding(call: call)
        return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
    }

    func addingAssetsTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recepient: AccountId,
        info: AssetsPalletStorageInfo
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        let call = callFactory.assetsTransfer(
            to: recepient,
            info: info,
            amount: amount.value
        )

        let newBuilder = try builder.adding(call: call)
        return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
    }

    func addingEquilibriumTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recepient: AccountId,
        extras: EquilibriumAssetExtras
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        let call = callFactory.equilibriumTransfer(
            to: recepient,
            extras: extras,
            amount: amount.value
        )

        let newBuilder = try builder.adding(call: call)
        return (newBuilder, CallCodingPath(moduleName: call.moduleName, callName: call.callName))
    }

    func fetchAssetExistence(
        for assetStorageInfo: AssetStorageInfo,
        completionClosure: @escaping (Result<AssetBalanceExistence, Error>) -> Void
    ) {
        let wrapper = assetStorageInfoFactory.createAssetBalanceExistenceOperation(
            for: assetStorageInfo,
            chainId: chain.chainId,
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

    func createAssetExtractionWrapper() -> CompoundOperationWrapper<(AssetStorageInfo, AssetStorageInfo?)> {
        let sendingAssetWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: asset,
            runtimeProvider: runtimeService
        )

        var dependencies = sendingAssetWrapper.allOperations

        let utilityAssetWrapper: CompoundOperationWrapper<AssetStorageInfo>?

        if !isUtilityTransfer, let utilityAsset = chain.utilityAssets().first {
            let wrapper = assetStorageInfoFactory.createStorageInfoWrapper(
                from: utilityAsset,
                runtimeProvider: runtimeService
            )

            utilityAssetWrapper = wrapper

            dependencies.append(contentsOf: wrapper.allOperations)
        } else {
            utilityAssetWrapper = nil
        }

        let mergeOperation = ClosureOperation<(AssetStorageInfo, AssetStorageInfo?)> {
            let sending = try sendingAssetWrapper.targetOperation.extractNoCancellableResultData()
            let utility = try utilityAssetWrapper?.targetOperation.extractNoCancellableResultData()

            return (sending, utility)
        }

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    func continueSetup() {
        feeProxy.delegate = self

        setupSendingAssetBalanceProvider()
        setupUtilityAssetBalanceProviderIfNeeded()
        setupSendingAssetPriceProviderIfNeeded()
        setupUtilityAssetPriceProviderIfNeeded()

        provideMinBalance()

        presenter?.didCompleteSetup()
    }

    func provideMinBalance() {
        if let sendingAssetInfo = sendingAssetInfo {
            fetchAssetExistence(for: sendingAssetInfo) { [weak self] result in
                switch result {
                case let .success(existence):
                    self?.presenter?.didReceiveSendingAssetExistence(existence)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        if let utilityAssetInfo = utilityAssetInfo {
            fetchAssetExistence(for: utilityAssetInfo) { [weak self] result in
                switch result {
                case let .success(existence):
                    self?.presenter?.didReceiveUtilityAssetMinBalance(existence.minBalance)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        }
    }

    func cancelSetupCall() {
        let cancellingCall = setupCall
        setupCall = nil
        cancellingCall?.cancel()
    }

    func subscribeUtilityRecepientAssetBalance() {
        guard
            let utilityAssetInfo = utilityAssetInfo,
            let recepientAccountId = recepientAccountId,
            recepientAccountId != selectedAccount.accountId,
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

    func subscribeSendingRecepientAssetBalance() {
        guard
            let sendingAssetInfo = sendingAssetInfo,
            let recepientAccountId = recepientAccountId,
            recepientAccountId != selectedAccount.accountId else {
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

    func clearSendingAssetRemoteRecepientSubscription() {
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

    func clearSendingAssetLocaleRecepientSubscription() {
        recepientSendingAssetProvider?.removeObserver(self)
        recepientSendingAssetProvider = nil
    }

    func clearUtilityAssetRemoteRecepientSubscriptions() {
        guard
            let utilityAssetInfo = utilityAssetInfo,
            let recepientAccountId = recepientAccountId,
            let utilityAssetSubscriptionId = utilityAssetSubscriptionId,
            let utilityAsset = chain.utilityAssets().first else {
            return
        }

        walletRemoteWrapper.unsubscribe(
            from: utilityAssetSubscriptionId,
            assetStorageInfo: utilityAssetInfo,
            accountId: recepientAccountId,
            chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: utilityAsset.assetId),
            completion: nil
        )

        self.utilityAssetSubscriptionId = nil
    }

    func clearUtilityAssetLocaleRecepientSubscriptions() {
        recepientUtilityAssetProvider?.removeObserver(self)
        recepientUtilityAssetProvider = nil
    }
}

extension OnChainTransferInteractor {
    func setup() {
        let wrapper = createAssetExtractionWrapper()

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.setupCall === wrapper else {
                    return
                }

                self?.setupCall = nil

                do {
                    let (sending, utility) = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.sendingAssetInfo = sending
                    self?.utilityAssetInfo = utility

                    self?.continueSetup()
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        setupCall = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func change(feeAsset: ChainAsset?) {
        self.feeAsset = feeAsset
    }

    func requestFeePaymentAvailability(for chainAsset: ChainAsset) {
        let wrapper = transferAggregationWrapperFactory.createCanPayFeeWrapper(in: chainAsset)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main,
            callbackClosure: { [weak self] result in
                switch result {
                case let .success(available):
                    self?.presenter?.didReceiveCustomAssetFeeAvailable(available)
                case let .failure(error) where error is AssetFeePaymentError:
                    self?.presenter?.didReceiveCustomAssetFeeAvailable(false)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        )
    }

    func change(recepient: AccountId?) {
        guard recepient != recepientAccountId else {
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

extension OnChainTransferInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(
        result: Result<ExtrinsicFeeProtocol, Error>,
        for transactionFeeId: TransactionFeeId
    ) {
        processFee(result: result, for: transactionFeeId)
    }
}
