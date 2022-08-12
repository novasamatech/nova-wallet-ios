import UIKit

final class CustomValidatorListInteractor {
    weak var presenter: CustomValidatorListInteractorOutputProtocol!

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let selectedAsset: AssetModel

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        selectedAsset: AssetModel,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.selectedAsset = selectedAsset
        self.currencyManager = currencyManager
    }
}

extension CustomValidatorListInteractor: CustomValidatorListInteractorInputProtocol {
    func setup() {
        if let priceId = selectedAsset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }
    }
}

extension CustomValidatorListInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension CustomValidatorListInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }
        
        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
