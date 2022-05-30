import UIKit

final class ParaStkCollatorInfoInteractor {
    weak var presenter: ParaStkCollatorInfoInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        chainAsset: ChainAsset,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
    }
}

extension ParaStkCollatorInfoInteractor: ParaStkCollatorInfoInteractorInputProtocol {
    func setup() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter?.didReceivePrice(result: .success(nil))
        }
    }

    func reload() {
        priceProvider?.refresh()
    }
}

extension ParaStkCollatorInfoInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {
        presenter?.didReceivePrice(result: result)
    }
}
