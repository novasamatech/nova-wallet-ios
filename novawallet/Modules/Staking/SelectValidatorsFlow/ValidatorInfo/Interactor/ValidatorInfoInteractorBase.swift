import RobinHood

class ValidatorInfoInteractorBase: ValidatorInfoInteractorInputProtocol {
    weak var presenter: ValidatorInfoInteractorOutputProtocol!

    let selectedAsset: AssetModel
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        selectedAsset: AssetModel,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedAsset = selectedAsset
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.currencyManager = currencyManager
    }

    func setup() {
        if let priceId = selectedAsset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }
    }

    func reload() {
        priceProvider?.refresh()
    }
}

extension ValidatorInfoInteractorBase: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension ValidatorInfoInteractorBase: SelectedCurrencyDepending {
    func applyCurrency() {
        if let priceId = selectedAsset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }
}
