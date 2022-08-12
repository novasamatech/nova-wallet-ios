import UIKit
import RobinHood

class WalletsListInteractor {
    weak var basePresenter: WalletsListInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private(set) var priceSubscription: AnySingleValueProvider<[PriceData]>?
    private(set) var assetsSubscription: StreamableProvider<AssetBalance>?
    private(set) var walletsSubscription: StreamableProvider<ManagedMetaAccountModel>?
    private(set) var availableTokenPrice: [ChainAssetId: AssetModel.PriceId] = [:]

    init(
        chainRegistry: ChainRegistryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.currencyManager = currencyManager
    }

    private func subscribeWallets() {
        walletsSubscription = subscribeAllWalletsProvider()
    }

    private func subscribeAssets() {
        assetsSubscription = subscribeAllBalancesProvider()
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.basePresenter?.didReceiveChainChanges(changes)
            self?.handle(changes: changes)
        }
    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        let prevPrices = availableTokenPrice
        for change in changes {
            switch change {
            case let .insert(chain), let .update(chain):
                availableTokenPrice = availableTokenPrice.filter { $0.key.chainId != chain.chainId }

                availableTokenPrice = chain.assets.reduce(into: availableTokenPrice) { result, asset in
                    guard let priceId = asset.priceId else {
                        return
                    }

                    let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
                    result[chainAssetId] = priceId
                }
            case let .delete(deletedIdentifier):
                availableTokenPrice = availableTokenPrice.filter { $0.key.chainId != deletedIdentifier }
            }
        }

        if prevPrices != availableTokenPrice {
            updatePriceProvider(
                for: Set(availableTokenPrice.values),
                currency: selectedCurrency
            )
        }
    }

    private func updatePriceProvider(
        for priceIdSet: Set<AssetModel.PriceId>,
        currency: Currency
    ) {
        priceSubscription = nil

        let priceIds = Array(priceIdSet).sorted()

        guard !priceIds.isEmpty else {
            return
        }

        priceSubscription = priceLocalSubscriptionFactory.getPriceListProvider(
            for: priceIds,
            currency: currency
        )

        let updateClosure = { [weak self] (changes: [DataProviderChange<[PriceData]>]) in
            if let prices = changes.reduceToLastChange() {
                let chainPrices = zip(priceIds, prices).reduce(
                    into: [ChainAssetId: PriceData]()
                ) { result, item in
                    guard let chainAssetIds = self?.availableTokenPrice.filter({ $0.value == item.0 })
                        .map(\.key) else {
                        return
                    }

                    for chainAssetId in chainAssetIds {
                        result[chainAssetId] = item.1
                    }
                }

                self?.basePresenter?.didReceivePrices(chainPrices)
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.basePresenter?.didReceiveError(error)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false
        )

        priceSubscription?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }
}

extension WalletsListInteractor: WalletsListInteractorInputProtocol {
    func setup() {
        subscribeChains()
        subscribeAssets()
        subscribeWallets()
    }
}

extension WalletsListInteractor: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {
        switch result {
        case let .success(changes):
            basePresenter?.didReceiveWalletsChanges(changes)
        case let .failure(error):
            basePresenter?.didReceiveError(error)
        }
    }
}

extension WalletsListInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAllBalances(result: Result<[DataProviderChange<AssetBalance>], Error>) {
        switch result {
        case let .success(changes):
            basePresenter?.didReceiveBalancesChanges(changes)
        case let .failure(error):
            basePresenter?.didReceiveError(error)
        }
    }
}

extension WalletsListInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        updatePriceProvider(for: Set(availableTokenPrice.values), currency: selectedCurrency)
    }
}
