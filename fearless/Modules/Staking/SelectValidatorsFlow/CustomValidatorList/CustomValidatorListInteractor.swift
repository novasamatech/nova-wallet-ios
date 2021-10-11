import UIKit

final class CustomValidatorListInteractor {
    weak var presenter: CustomValidatorListInteractorOutputProtocol!

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let selectedAsset: AssetModel

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        selectedAsset: AssetModel,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.selectedAsset = selectedAsset
    }
}

extension CustomValidatorListInteractor: CustomValidatorListInteractorInputProtocol {
    func setup() {
        if let priceId = selectedAsset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
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
