import UIKit
import Operation_iOS

final class CollatorStakingSelectInteractor: AnyProviderAutoCleaning {
    weak var presenter: CollatorStakingSelectInteractorOutputProtocol?

    var chain: ChainModel { chainAsset.chain }

    let chainAsset: ChainAsset
    let stakableCollatorOperationFactory: CollatorStakingStakableFactoryProtocol
    let preferredCollatorsProvider: PreferredValidatorsProviding
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue

    private var priceProvider: StreamableProvider<PriceData>?

    init(
        chainAsset: ChainAsset,
        stakableCollatorOperationFactory: CollatorStakingStakableFactoryProtocol,
        preferredCollatorsProvider: PreferredValidatorsProviding,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.stakableCollatorOperationFactory = stakableCollatorOperationFactory
        self.preferredCollatorsProvider = preferredCollatorsProvider
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    private func providePreferredCollators() {
        let wrapper = preferredCollatorsProvider.createPreferredValidatorsWrapper(for: chain)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(prefs):
                self?.presenter?.didReceiveCollatorsPref(prefs)
            case let .failure(error):
                self?.presenter?.didReceiveError(.allCollatorsFailed(error))
            }
        }
    }

    private func provideElectedCollatorsInfo() {
        let wrapper = stakableCollatorOperationFactory.stakableCollatorsWrapper()

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(collators):
                self?.presenter?.didReceiveAllCollators(collators)
            case let .failure(error):
                self?.presenter?.didReceiveError(.allCollatorsFailed(error))
            }
        }
    }

    private func updatePriceSubscription() {
        clear(streamableProvider: &priceProvider)

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }
}

extension CollatorStakingSelectInteractor: CollatorStakingSelectInteractorInputProtocol {
    func setup() {
        provideElectedCollatorsInfo()
        providePreferredCollators()

        updatePriceSubscription()
    }

    func refresh() {
        provideElectedCollatorsInfo()
        providePreferredCollators()
    }

    func retrySubscription() {
        updatePriceSubscription()
    }
}

extension CollatorStakingSelectInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {
        switch result {
        case let .success(priceData):
            presenter?.didReceivePrice(priceData)
        case let .failure(error):
            presenter?.didReceiveError(.priceFailed(error))
        }
    }
}

extension CollatorStakingSelectInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil, chainAsset.asset.priceId != nil else {
            return
        }

        updatePriceSubscription()
    }
}
