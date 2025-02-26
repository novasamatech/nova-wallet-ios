import Foundation
import Operation_iOS

enum BalancesStoreError: Error {
    case priceFailed(Error)
    case balancesFailed(Error)
    case externalBalancesFailed(Error)
}

protocol BalancesStoreDelegate: AnyObject {
    func balancesStore(_ balancesStore: BalancesStoreProtocol, didUpdate calculator: BalancesCalculating)
    func balancesStore(_ balancesStore: BalancesStoreProtocol, didReceive error: BalancesStoreError)
}

protocol BalancesStoreProtocol: AnyObject {
    var delegate: BalancesStoreDelegate? { get set }

    func setup()
}

final class BalancesStore: AnyProviderAutoCleaning {
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol

    weak var delegate: BalancesStoreDelegate?

    private(set) var priceSubscription: StreamableProvider<PriceData>?
    private(set) var assetsSubscription: StreamableProvider<AssetBalance>?
    private(set) var walletsSubscription: StreamableProvider<ManagedMetaAccountModel>?
    private(set) var externalBalancesSubscription: StreamableProvider<ExternalAssetBalance>?
    private(set) var availableTokenPrice: [ChainAssetId: AssetModel.PriceId] = [:]

    private var calculator: BalancesCalculator?

    init(
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.externalBalancesSubscriptionFactory = externalBalancesSubscriptionFactory
        self.currencyManager = currencyManager
    }

    private func subscribeAssets() {
        assetsSubscription = subscribeAllBalancesProvider()
    }

    private func subscribeToExternalBalances() {
        externalBalancesSubscription = subscribeToAllExternalAssetBalancesProvider()
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.calculator?.didReceiveChainChanges(changes)
            self?.handle(changes: changes)
            self?.notifyCalculatorChanges()
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
            updatePriceProvider(currency: selectedCurrency)
        }
    }

    private func notifyCalculatorChanges() {
        if let calculator = calculator {
            delegate?.balancesStore(self, didUpdate: calculator)
        }
    }

    private func notify(error: BalancesStoreError) {
        delegate?.balancesStore(self, didReceive: error)
    }

    private func updatePriceProvider(currency: Currency) {
        priceSubscription = nil
        priceSubscription = priceLocalSubscriptionFactory.getAllPricesStreamableProvider(currency: currency)

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
            strongSelf.notifyCalculatorChanges()

            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.notify(error: .priceFailed(error))
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

extension BalancesStore: BalancesStoreProtocol {
    func setup() {
        calculator = BalancesCalculator()

        subscribeChains()
        subscribeAssets()
        subscribeToExternalBalances()
    }
}

extension BalancesStore: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAllBalances(result: Result<[DataProviderChange<AssetBalance>], Error>) {
        switch result {
        case let .success(changes):
            calculator?.didReceiveBalancesChanges(changes)
            notifyCalculatorChanges()
        case let .failure(error):
            notify(error: .balancesFailed(error))
        }
    }
}

extension BalancesStore: ExternalAssetBalanceSubscriptionHandler, ExternalAssetBalanceSubscriber {
    func handleAllExternalAssetBalances(
        result: Result<[DataProviderChange<ExternalAssetBalance>], Error>
    ) {
        switch result {
        case let .success(changes):
            calculator?.didReceiveExternalBalanceChanges(changes)
            notifyCalculatorChanges()
        case let .failure(error):
            notify(error: .externalBalancesFailed(error))
        }
    }
}

extension BalancesStore: SelectedCurrencyDepending {
    func applyCurrency() {
        guard delegate != nil else {
            return
        }

        updatePriceProvider(currency: selectedCurrency)
    }
}
