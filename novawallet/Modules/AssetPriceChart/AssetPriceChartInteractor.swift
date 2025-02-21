import UIKit
import Operation_iOS

final class AssetPriceChartInteractor {
    weak var presenter: AssetPriceChartInteractorOutputProtocol?

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let asset: AssetModel
    var currency: Currency

    private var priceSubscription: StreamableProvider<PriceData>?

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        asset: AssetModel,
        currency: Currency
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.asset = asset
        self.currency = currency
    }
}

// MARK: Private

private extension AssetPriceChartInteractor {
    func subscribePrice() {
        if let priceId = asset.priceId {
            priceSubscription = subscribeToPrice(
                for: priceId,
                currency: currency
            )
        } else {
            presenter?.didReceive(price: nil)
        }
    }
}

extension AssetPriceChartInteractor: AssetPriceChartInteractorInputProtocol {
    func updateSelectedCurrency(_: Currency) {
        // TODO: Implement after network logic
    }

    func setup() {
        subscribePrice()

        // TODO: Implement fetch logic
        presenter?.didReceive(
            prices: [
                .day: prices1D,
                .week: prices1W,
                .month: prices1M,
                .year: prices1M,
                .allTime: prices1M
            ]
        )
    }
}

// MARK: PriceLocalStorageSubscriber

extension AssetPriceChartInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceive(price: priceData)
        case let .failure(error):
            presenter?.didReceive(error)
        }
    }
}
