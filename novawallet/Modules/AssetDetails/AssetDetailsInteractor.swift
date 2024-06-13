import UIKit
import Operation_iOS

final class AssetDetailsInteractor: AnyCancellableCleaning {
    weak var presenter: AssetDetailsInteractorOutputProtocol?
    let chainAsset: ChainAsset
    let selectedMetaAccount: MetaAccountModel
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol
    let assetConvertionAggregator: AssetConversionAggregationFactoryProtocol
    let purchaseProvider: PurchaseProviderProtocol
    let assetMapper: CustomAssetMapper
    let operationQueue: OperationQueue

    private var assetLocksSubscription: StreamableProvider<AssetLock>?
    private var priceSubscription: StreamableProvider<PriceData>?
    private var assetBalanceSubscription: StreamableProvider<AssetBalance>?
    private var externalBalanceSubscription: StreamableProvider<ExternalAssetBalance>?
    private var swapsCall = CancellableCallStore()

    private var accountId: AccountId? {
        selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId
    }

    init(
        selectedMetaAccount: MetaAccountModel,
        chainAsset: ChainAsset,
        purchaseProvider: PurchaseProviderProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol,
        assetConvertionAggregator: AssetConversionAggregationFactoryProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.externalBalancesSubscriptionFactory = externalBalancesSubscriptionFactory
        self.selectedMetaAccount = selectedMetaAccount
        self.chainAsset = chainAsset
        self.purchaseProvider = purchaseProvider
        self.assetConvertionAggregator = assetConvertionAggregator
        self.operationQueue = operationQueue
        assetMapper = CustomAssetMapper(
            type: chainAsset.asset.type,
            typeExtras: chainAsset.asset.typeExtras
        )
        self.currencyManager = currencyManager
    }

    deinit {
        swapsCall.cancel()
    }

    private func subscribePrice() {
        if let priceId = chainAsset.asset.priceId {
            priceSubscription = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceive(price: nil)
        }
    }

    private func fetchSwapsAndProvideOperations() {
        swapsCall.cancel()

        guard chainAsset.chain.hasSwaps else {
            return
        }

        let wrapper = assetConvertionAggregator.createAvailableDirectionsWrapper(for: chainAsset)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: swapsCall,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self = self else {
                return
            }

            switch result {
            case let .success(directions):
                let hasSwaps = !directions.isEmpty
                self.setAvailableOperations(hasSwaps: hasSwaps)
            case let .failure(error):
                self.presenter?.didReceive(error: .swaps(error))
            }
        }
    }

    private func setAvailableOperations(hasSwaps: Bool) {
        guard let accountId = accountId else {
            return
        }
        var operations: AssetDetailsOperation = .init()
        let isTransfersEnable = try? assetMapper.transfersEnabled()
        if isTransfersEnable == true {
            operations.insert(.send)
        }

        let actions: [PurchaseAction] = purchaseProvider.buildPurchaseActions(
            for: chainAsset,
            accountId: accountId
        )

        if !actions.isEmpty {
            operations.insert(.buy)
        }

        operations.insert(.receive)

        if hasSwaps {
            operations.insert(.swap)
        }

        presenter?.didReceive(purchaseActions: actions)
        presenter?.didReceive(availableOperations: operations)
    }
}

extension AssetDetailsInteractor: AssetDetailsInteractorInputProtocol {
    func setup() {
        guard let accountId = accountId else {
            return
        }
        subscribePrice()
        assetBalanceSubscription = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
        assetLocksSubscription = subscribeToLocksProvider(
            for: accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        if chainAsset.chain.chainAssetIdsWithExternalBalances().contains(chainAsset.chainAssetId) {
            externalBalanceSubscription = subscribeToExternalAssetBalancesProvider(
                for: accountId,
                chainAsset: chainAsset
            )
        } else {
            externalBalanceSubscription = nil
        }

        setAvailableOperations(hasSwaps: false)

        if chainAsset.chain.hasSwaps {
            fetchSwapsAndProvideOperations()
        }
    }
}

extension AssetDetailsInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard chainId == chainAsset.chain.chainId,
              assetId == chainAsset.asset.assetId,
              accountId == self.accountId else {
            return
        }

        switch result {
        case let .success(balance):
            presenter?.didReceive(balance: balance ?? AssetBalance.createZero(
                for: chainAsset.chainAssetId,
                accountId: accountId
            ))
        case let .failure(error):
            presenter?.didReceive(error: .swaps(error))
        }
    }

    func handleAccountLocks(
        result: Result<[DataProviderChange<AssetLock>], Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard chainId == chainAsset.chain.chainId,
              assetId == chainAsset.asset.assetId,
              accountId == self.accountId else {
            return
        }

        switch result {
        case let .failure(error):
            presenter?.didReceive(error: .locks(error))
        case let .success(changes):
            presenter?.didReceive(lockChanges: changes)
        }
    }
}

extension AssetDetailsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceive(price: priceData)
        case let .failure(error):
            presenter?.didReceive(error: .price(error))
        }
    }
}

extension AssetDetailsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil, let priceId = chainAsset.asset.priceId {
            priceSubscription = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }
}

extension AssetDetailsInteractor: ExternalAssetBalanceSubscriber, ExternalAssetBalanceSubscriptionHandler {
    func handleExternalAssetBalances(
        result: Result<[DataProviderChange<ExternalAssetBalance>], Error>,
        accountId _: AccountId,
        chainAsset _: ChainAsset
    ) {
        switch result {
        case let .success(externalBalanceChanges):
            presenter?.didReceive(externalBalanceChanges: externalBalanceChanges)
        case let .failure(error):
            presenter?.didReceive(error: .externalBalances(error))
        }
    }
}
