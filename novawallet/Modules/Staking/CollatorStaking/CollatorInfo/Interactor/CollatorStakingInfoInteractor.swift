import UIKit
import Operation_iOS

class CollatorStakingInfoInteractor {
    weak var presenter: CollatorStakingInfoInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private var priceProvider: StreamableProvider<PriceData>?

    init(
        chainAsset: ChainAsset,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.currencyManager = currencyManager
    }

    func onSetup() {}

    func onReload() {}
}

extension CollatorStakingInfoInteractor: CollatorStakingInfoInteractorInputProtocol {
    func setup() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceivePrice(nil)
        }

        onSetup()
    }

    func reload() {
        priceProvider?.refresh()

        onReload()
    }
}

extension CollatorStakingInfoInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {
        switch result {
        case let .success(price):
            presenter?.didReceivePrice(price)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension CollatorStakingInfoInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
