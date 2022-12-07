import UIKit
import RobinHood

final class AssetDetailsInteractor {
    weak var presenter: AssetDetailsInteractorOutputProtocol!
    let chainAsset: ChainAsset
    var chain: ChainModel { chainAsset.chain }
    var asset: AssetModel { chainAsset.asset }
    let selectedMetaAccount: MetaAccountModel
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let purchaseProvider: PurchaseProviderProtocol

    private var assetLocksSubscription: StreamableProvider<AssetLock>?
    private var priceSubscription: AnySingleValueProvider<PriceData>?
    private var assetBalanceSubscription: StreamableProvider<AssetBalance>?

    private var locks: [AssetLock] = []
    private var accountId: AccountId? {
        selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId
    }

    init(
        selectedMetaAccount: MetaAccountModel,
        chainAsset: ChainAsset,
        purchaseProvider: PurchaseProviderProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.selectedMetaAccount = selectedMetaAccount
        self.chainAsset = chainAsset
        self.currencyManager = currencyManager
        self.purchaseProvider = purchaseProvider
    }

    private func subscribePrice() {
        if let priceId = asset.priceId {
            priceSubscription = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter.didReceive(price: nil)
        }
    }

    private var isTransfersEnable: Bool {
        if let type = asset.type {
            switch AssetType(rawValue: type) {
            case .statemine, .none:
                return true
            case .orml:
                if let extras = try? asset.typeExtras?.map(to: OrmlTokenExtras.self) {
                    return extras.transfersEnabled ?? true
                } else {
                    return false
                }
            }
        } else {
            return true
        }
    }

    private func setAvailableOperations() {
        guard let accountId = accountId else {
            return
        }
        let assetId = chainAsset.chainAssetId.walletId
        let operations: Operations

        if isTransfersEnable {
            operations.insert(.send)
        }

        let actions = purchaseProvider.buildPurchaseActions(
            for: chainAsset,
            accountId: accountId
        )

        if !actions.isEmpty {
            operations.insert(.buy)
        }

        operations.insert(.receive)

        presenter.didReceive(purchaseActions: actions)
        presenter.didReceive(availableOperations: operations)
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
            chainId: chain.chainId,
            assetId: asset.assetId
        )
        assetLocksSubscription = subscribeToLocksProvider(
            for: accountId,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
        setAvailableOperations()
    }
}

extension AssetDetailsInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard chainId == chain.chainId,
              assetId == asset.assetId,
              accountId == self.accountId else {
            return
        }

        switch result {
        case let .success(balance):
            presenter.didReceive(balance: balance)
        case let .failure(error):
            presenter.didReceive(error: .accountBalance(error))
        }
    }

    func handleAccountLocks(
        result: Result<[DataProviderChange<AssetLock>], Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard chainId == chain.chainId,
              assetId == asset.assetId,
              accountId == self.accountId else {
            return
        }

        switch result {
        case let .failure(error):
            presenter.didReceive(error: .locks(error))
        case let .success(changes):
            locks = changes.reduce(into: locks) { result, change in
                switch change {
                case let .insert(lock), let .update(lock):
                    result.addOrReplaceSingle(lock)
                case let .delete(deletedIdentifier):
                    result = result.filter { $0.identifier != deletedIdentifier }
                }
            }

            presenter.didReceive(locks: locks)
        }
    }
}

extension AssetDetailsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter.didReceive(price: priceData)
        case let .failure(error):
            presenter.didReceive(error: .price(error))
        }
    }
}

extension AssetDetailsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil, let priceId = asset.priceId {
            priceSubscription = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }
}
