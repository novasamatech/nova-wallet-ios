import UIKit
import Operation_iOS

final class ParaStkSelectCollatorsInteractor: AnyProviderAutoCleaning {
    weak var presenter: ParaStkSelectCollatorsInteractorOutputProtocol?

    var chain: ChainModel { chainAsset.chain }

    let chainAsset: ChainAsset
    let collatorService: ParachainStakingCollatorServiceProtocol
    let rewardService: CollatorStakingRewardCalculatorServiceProtocol
    let collatorOperationFactory: ParaStkCollatorsOperationFactoryProtocol
    let preferredCollatorsProvider: PreferredValidatorsProviding
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue

    private var priceProvider: StreamableProvider<PriceData>?

    init(
        chainAsset: ChainAsset,
        collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: CollatorStakingRewardCalculatorServiceProtocol,
        collatorOperationFactory: ParaStkCollatorsOperationFactoryProtocol,
        preferredCollatorsProvider: PreferredValidatorsProviding,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.collatorService = collatorService
        self.rewardService = rewardService
        self.preferredCollatorsProvider = preferredCollatorsProvider
        self.collatorOperationFactory = collatorOperationFactory
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
        let wrapper = collatorOperationFactory.electedCollatorsInfoOperation(
            for: collatorService,
            rewardService: rewardService
        )

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

extension ParaStkSelectCollatorsInteractor: ParaStkSelectCollatorsInteractorInputProtocol {
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

extension ParaStkSelectCollatorsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
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

extension ParaStkSelectCollatorsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil, chainAsset.asset.priceId != nil else {
            return
        }

        updatePriceSubscription()
    }
}
