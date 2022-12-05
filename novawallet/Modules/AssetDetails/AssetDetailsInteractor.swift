import UIKit
import RobinHood

final class AssetDetailsInteractor {
    weak var presenter: AssetDetailsInteractorOutputProtocol!
    let chain: ChainModel
    let asset: AssetModel
    let selectedMetaAccount: MetaAccountModel

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var locks: [AssetLock] = []
    private var accountId: AccountId? {
        selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId
    }

    init(
        selectedMetaAccount: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chain = chain
        self.asset = asset
    }

    private func subscribePrice() {
        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter.didReceive(price: nil)
        }
    }
}

extension AssetDetailsInteractor: AssetDetailsInteractorInputProtocol {
    func setup() {
        guard let accountId = accountId else {
            return
        }
        subscribePrice()
        subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
        subscribeToLocksProvider(
            for: accountId,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
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
            changes.reduce(into: locks) { result, change in
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
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }
}
