import UIKit
import RobinHood

class WalletsListInteractor {
    weak var basePresenter: WalletsListInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactoryProtocol

    private(set) var priceSubscription: StreamableProvider<PriceData>?
    private(set) var assetsSubscription: StreamableProvider<AssetBalance>?
    private(set) var walletsSubscription: StreamableProvider<ManagedMetaAccountModel>?
    private(set) var crowdloansSubscription: StreamableProvider<CrowdloanContributionData>?
    private(set) var availableTokenPrice: [ChainAssetId: AssetModel.PriceId] = [:]

    init(
        chainRegistry: ChainRegistryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactoryProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.crowdloansLocalSubscriptionFactory = crowdloansLocalSubscriptionFactory
        self.currencyManager = currencyManager
    }

    private func subscribeWallets() {
        walletsSubscription = subscribeAllWalletsProvider()
    }

    private func subscribeAssets() {
        assetsSubscription = subscribeAllBalancesProvider()
    }

    private func subscribeToCrowdloans() {
        crowdloansSubscription = subscribeToAllCrowdloansProvider()
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

        priceSubscription = priceLocalSubscriptionFactory.getAllPricesStreamableProvider(
            for: priceIds,
            currency: currency
        )

        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            guard let strongSelf = self else {
                return
            }

            let mappedChanges = changes.reduce(
                using: .init(),
                availableTokenPrice: strongSelf.availableTokenPrice,
                currency: currency
            )

            self?.basePresenter?.didReceivePrice(mappedChanges)

            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.basePresenter?.didReceiveError(error)
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: false
        )

        priceSubscription?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        priceSubscription?.refresh()
    }
}

extension WalletsListInteractor: WalletsListInteractorInputProtocol {
    func setup() {
        subscribeChains()
        subscribeAssets()
        subscribeWallets()
        subscribeToCrowdloans()
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
        guard basePresenter != nil else {
            return
        }

        updatePriceProvider(for: Set(availableTokenPrice.values), currency: selectedCurrency)
    }
}

extension WalletsListInteractor: CrowdloanContributionLocalSubscriptionHandler, CrowdloansLocalStorageSubscriber {
    func handleAllCrowdloans(result: Result<[DataProviderChange<CrowdloanContributionData>], Error>) {
        switch result {
        case let .success(changes):
            basePresenter?.didReceiveCrowdloanContributionChanges(changes)
        case let .failure(error):
            basePresenter?.didReceiveError(error)
        }
    }
}
