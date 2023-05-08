import Foundation
import RobinHood

enum BalancesStoreError: Error {
    case priceFailed(Error)
    case balancesFailed(Error)
    case crowdloansFailed(Error)
}

protocol BalancesStoreDelegate: AnyObject {
    func balancesStore(_ balancesStore: BalancesStoreProtocol, didUpdate calculator: BalancesCalculating)
    func balancesStore(_ balancesStore: BalancesStoreProtocol, didReceive error: BalancesStoreError)
}

protocol BalancesStoreProtocol: AnyObject {
    var delegate: BalancesStoreDelegate? { get set }

    func setup()
}

final class BalancesStore {
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactoryProtocol

    weak var delegate: BalancesStoreDelegate?

    private(set) var priceSubscription: StreamableProvider<PriceData>?
    private(set) var assetsSubscription: StreamableProvider<AssetBalance>?
    private(set) var walletsSubscription: StreamableProvider<ManagedMetaAccountModel>?
    private(set) var crowdloansSubscription: StreamableProvider<CrowdloanContributionData>?
    private(set) var availableTokenPrice: [ChainAssetId: AssetModel.PriceId] = [:]

    private var calculator: BalancesCalculator?

    init(
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactoryProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.crowdloansLocalSubscriptionFactory = crowdloansLocalSubscriptionFactory
        self.currencyManager = currencyManager
    }

    private func subscribeAssets() {
        assetsSubscription = subscribeAllBalancesProvider()
    }

    private func subscribeToCrowdloans() {
        crowdloansSubscription = subscribeToAllCrowdloansProvider()
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.calculator?.didReceiveChainChanges(changes)
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

            strongSelf.calculator?.didReceivePrice(mappedChanges)

            return
        }

        let failureClosure = { [weak self] (error: Error) in
            guard let strongSelf = self else {
                return
            }

            strongSelf.delegate?.balancesStore(strongSelf, didReceive: .priceFailed(error))
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

extension BalancesStore: BalancesStoreProtocol {
    func setup() {
        calculator = BalancesCalculator()

        subscribeChains()
        subscribeAssets()
        subscribeToCrowdloans()
    }
}

extension BalancesStore: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAllBalances(result: Result<[DataProviderChange<AssetBalance>], Error>) {
        switch result {
        case let .success(changes):
            calculator?.didReceiveBalancesChanges(changes)
        case let .failure(error):
            delegate?.balancesStore(self, didReceive: .balancesFailed(error))
        }
    }
}

extension BalancesStore: CrowdloanContributionLocalSubscriptionHandler, CrowdloansLocalStorageSubscriber {
    func handleAllCrowdloans(result: Result<[DataProviderChange<CrowdloanContributionData>], Error>) {
        switch result {
        case let .success(changes):
            calculator?.didReceiveCrowdloanContributionChanges(changes)
        case let .failure(error):
            delegate?.balancesStore(self, didReceive: .crowdloansFailed(error))
        }
    }
}

extension BalancesStore: SelectedCurrencyDepending {
    func applyCurrency() {
        guard delegate != nil else {
            return
        }

        updatePriceProvider(for: Set(availableTokenPrice.values), currency: selectedCurrency)
    }
}
