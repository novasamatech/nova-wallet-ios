import UIKit
import RobinHood

final class StakingRewardDetailsInteractor {
    weak var presenter: StakingRewardDetailsInteractorOutputProtocol!

    let asset: AssetModel
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(asset: AssetModel, priceLocalSubscriptionFactory: PriceProviderFactoryProtocol) {
        self.asset = asset
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
    }
}

extension StakingRewardDetailsInteractor: StakingRewardDetailsInteractorInputProtocol {
    func setup() {
        if let priceId = asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
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
