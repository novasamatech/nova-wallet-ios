import UIKit
import RobinHood

final class StakingRewardDetailsInteractor {
    weak var presenter: StakingRewardDetailsInteractorOutputProtocol!

    let asset: AssetModel
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        asset: AssetModel,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.asset = asset
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.currencyManager = currencyManager
    }
}

extension StakingRewardDetailsInteractor: StakingRewardDetailsInteractorInputProtocol {
    func setup() {
        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter.didReceive(priceResult: .success(nil))
        }
    }
}

extension StakingRewardDetailsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceive(priceResult: result)
    }
}

extension StakingRewardDetailsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }
        
        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
