import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

class GiftTransferInteractor: OnChainTransferBaseInteractor {
    let runtimeService: RuntimeCodingServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let walletRemoteWrapper: WalletRemoteSubscriptionWrapperProtocol
    let substrateStorageFacade: StorageFacadeProtocol
    let transferAggregationWrapperFactory: AssetTransferAggregationFactoryProtocol

    private lazy var callFactory = SubstrateCallFactory()
    private lazy var assetStorageInfoFactory = AssetStorageInfoOperationFactory()

    private var setupCall: CancellableCall?

    private var sendingAssetInfo: AssetStorageInfo?

    private(set) var feeAsset: ChainAsset?
    
    private var pendingFees: [TransactionFeeId: FeeType] = [:]

    private lazy var chainStorage: AnyDataProviderRepository<ChainStorageItem> = {
        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            substrateStorageFacade.createRepository()
        return AnyDataProviderRepository(storage)
    }()
    
    private let assetStorageCallStore = CancellableCallStore()

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

            guard
                accountId == selectedAccount.accountId,
                asset.assetId == assetId
            else { return }
            
            presenter?.didReceiveSendingAssetSenderBalance(balance)
        case .failure:
            presenter?.didReceiveError(CommonError.databaseSubscription)
        }
    }
}

// MARK: - Private

private extension GiftTransferInteractor {
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

    func continueSetup() {
        feeProxy.delegate = self

        setupSendingAssetBalanceProvider()
        setupSendingAssetPriceProviderIfNeeded()

        provideMinBalance()

        presenter?.didCompleteSetup()
    }

    func provideMinBalance() {
        guard let sendingAssetInfo else { return }
        
        let wrapper = assetStorageInfoFactory.createAssetBalanceExistenceOperation(
            for: sendingAssetInfo,
            chainId: chain.chainId,
            asset: asset
        )
        
        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(existence):
                self?.presenter?.didReceiveSendingAssetExistence(existence)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }

    func cancelSetupCall() {
        let cancellingCall = setupCall
        setupCall = nil
        cancellingCall?.cancel()
    }
    
    func estimateFee(
        for amount: OnChainTransferAmount<BigUInt>,
        feeType: FeeType
    ) {
        let recepientAccountId = AccountId.zeroAccountId(of: chain.accountIdSize)

        let transactionId = TransactionFeeId(
            recepientAccountId: recepientAccountId,
            amount: amount
        )
        
        pendingFees[transactionId] = feeType
        
        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: transactionId,
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
}

// MARK: - Internal

extension GiftTransferInteractor {
    func setup() {
        let assetStorageWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: asset,
            runtimeProvider: runtimeService
        )

        executeCancellable(
            wrapper: assetStorageWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: assetStorageCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(info):
                self?.sendingAssetInfo = info

                self?.continueSetup()
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }

    func change(feeAsset: ChainAsset?) {
        self.feeAsset = feeAsset
    }
    
    func estimateFee(for amount: OnChainTransferAmount<BigUInt>) {
        estimateFee(for: amount, feeType: .claimGift)
    }
}

// MARK: - ExtrinsicFeeProxyDelegate

extension GiftTransferInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(
        result: Result<ExtrinsicFeeProtocol, Error>,
        for transactionFeeId: TransactionFeeId
    ) {
        guard let feeType = pendingFees[transactionFeeId] else { return }
        
        pendingFees[transactionFeeId] = nil
        
        switch result {
        case let .success(info) where feeType == .claimGift:
            let amount = transactionFeeId.amount.map { $0 + info.amount }
            estimateFee(for: amount, feeType: .createGift)
        case let .success(info):
            let feeModel = FeeOutputModel(value: info, validationProvider: nil)
            presenter?.didReceiveFee(result: .success(feeModel))
        case let .failure(error):
            presenter?.didReceiveFee(result: .failure(error))
        }
    }
}

// MARK: - Private types

private extension GiftTransferInteractor {
    enum FeeType: Hashable {
        case createGift
        case claimGift
    }
}
