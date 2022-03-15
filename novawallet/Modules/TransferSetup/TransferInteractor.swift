import Foundation
import RobinHood
import BigInt
import SubstrateSdk

class TransferInteractor {
    weak var presenter: TransferSetupInteractorOutputProtocol?

    let selectedAccount: MetaChainAccountResponse
    let chain: ChainModel
    let asset: AssetModel
    let runtimeService: RuntimeCodingServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let walletRemoteWrapper: WalletRemoteSubscriptionWrapperProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
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

    init(
        selectedAccount: MetaChainAccountResponse,
        chain: ChainModel,
        asset: AssetModel,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        walletRemoteWrapper: WalletRemoteSubscriptionWrapperProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
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
        self.operationQueue = operationQueue
    }

    deinit {
        cancelCodingFactoryOperation()

        clearSendingAssetRemoteRecepientSubscriptions()
        clearUtilityAssetRemoteRecepientSubscriptions()
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
                } catch {
                    self?.presenter?.didReceiveSetup(error: error)
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

        if
            let utilityAsset = chain.utilityAssets().first,
            utilityAsset.assetId != asset.assetId {
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
        setupUtilityAssetBalanceProviderIfNeeded()
    }

    private func setupSendingAssetBalanceProvider() {
        sendingAssetProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
    }

    private func setupUtilityAssetBalanceProviderIfNeeded() {
        if
            let utilityAsset = chain.utilityAssets().first,
            asset.assetId != utilityAsset.assetId {
            utilityAssetProvider = subscribeToAssetBalanceProvider(
                for: selectedAccount.chainAccount.accountId,
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
            presenter?.didReceiveSendingAssetPrice(result: .success(nil))
        }
    }

    private func setupUtilityAssetPriceProviderIfNeeded() {
        guard
            let utilityAsset = chain.utilityAssets().first,
            asset.assetId != utilityAsset.assetId else {
            return
        }

        if let priceId = utilityAsset.priceId {
            let options = DataProviderObserverOptions(
                alwaysNotifyOnRefresh: false,
                waitsInProgressSyncOnAdd: false
            )

            utilityAssetPriceProvider = subscribeToPrice(for: priceId, options: options)
        } else {
            presenter?.didReceiveUtilityAssetPrice(result: .success(nil))
        }
    }

    func addingTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: BigUInt,
        recepient: AccountId
    ) throws -> ExtrinsicBuilderProtocol {
        guard let sendingAssetInfo = sendingAssetInfo else {
            return builder
        }

        switch sendingAssetInfo {
        case let .orml(currencyId, _, module):
            let call = callFactory.ormlTransfer(
                in: module,
                currencyId: currencyId,
                receiverId: recepient,
                amount: amount
            )

            return try builder.adding(call: call)
        case let .statemine(extras):
            let call = callFactory.assetsTransfer(
                to: recepient,
                assetId: extras.assetId,
                amount: amount
            )

            return try builder.adding(call: call)
        case .native:
            let call = callFactory.nativeTransfer(to: recepient, amount: amount)
            return try builder.adding(call: call)
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

    private func clearSendingAssetRemoteRecepientSubscriptions() {
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
            chainAsset: ChainAsset(chain: chain, asset: asset),
            completion: nil
        )

        self.sendingAssetSubscriptionId = nil
    }

    private func clearSendingAssetLocaleRecepientSubscriptions() {
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
            chainAsset: ChainAsset(chain: chain, asset: asset),
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
                recepientAccountId = selectedAccount.chainAccount.accountId
            }

            let identifier = String(amount) + "-" + recepientAccountId.toHex()

            feeProxy.estimateFee(
                using: extrinsicService,
                reuseIdentifier: identifier
            ) { [weak self] builder in
                try self?.addingTransferCommand(
                    to: builder,
                    amount: amount,
                    recepient: recepientAccountId
                ) ?? builder
            }
        } catch {
            presenter?.didReceiveFee(result: .failure(error))
        }
    }

    func change(recepient: AccountAddress?) {
        guard
            let newRecepientAccountId = try? recepient?.toAccountId(),
            newRecepientAccountId != recepientAccountId else {
            return
        }

        clearSendingAssetRemoteRecepientSubscriptions()
        clearUtilityAssetRemoteRecepientSubscriptions()
        clearSendingAssetLocaleRecepientSubscriptions()
        clearUtilityAssetLocaleRecepientSubscriptions()

        self.recepientAccountId = newRecepientAccountId

        subscribeSendingRecepientAssetBalance()
        subscribeUtilityRecepientAssetBalance()
    }
}

extension TransferInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        if asset.assetId == assetId {
            presenter?.didReceiveSendingAssetBalance(result: result)
        } else if chain.utilityAssets().first?.assetId == assetId {
            presenter?.didReceiveUtilityAssetBalance(result: result)
        }
    }
}

extension TransferInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if asset.priceId == priceId {
            presenter?.didReceiveSendingAssetPrice(result: result)
        } else if chain.utilityAssets().first?.priceId == priceId {
            presenter?.didReceiveUtilityAssetPrice(result: result)
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
