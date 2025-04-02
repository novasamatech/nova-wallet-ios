import UIKit
import Operation_iOS

final class AssetPriceChartInteractor: AnyProviderAutoCleaning {
    weak var presenter: AssetPriceChartInteractorOutputProtocol?

    let priceChartDataOperationFactory: PriceChartDataOperationFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let asset: AssetModel
    let operationQueue: OperationQueue

    var currency: Currency

    private var priceProvider: StreamableProvider<PriceData>?
    private let callStore = CancellableCallStore()

    init(
        priceChartDataOperationFactory: PriceChartDataOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        asset: AssetModel,
        operationQueue: OperationQueue,
        currency: Currency
    ) {
        self.priceChartDataOperationFactory = priceChartDataOperationFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.asset = asset
        self.operationQueue = operationQueue
        self.currency = currency
    }

    deinit {
        callStore.cancel()
    }
}

// MARK: Private

private extension AssetPriceChartInteractor {
    func fetchAndSubscribe() {
        guard let priceId = asset.priceId else {
            presenter?.didReceive(.missingPriceId)
            return
        }

        subscribePrice(priceId: priceId)
        fetchChartData(priceId: priceId)
    }

    func subscribePrice(priceId: AssetModel.PriceId) {
        clear(streamableProvider: &priceProvider)

        priceProvider = subscribeToPrice(
            for: priceId,
            currency: currency
        )
    }

    func fetchChartData(priceId: AssetModel.PriceId) {
        let wrapper = priceChartDataOperationFactory.createWrapper(
            tokenId: priceId,
            currency: currency
        )

        callStore.cancel()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(prices):
                self?.presenter?.didReceive(prices: prices)
            case .failure:
                self?.presenter?.didReceive(.chartDataNotAvailable)
            }
        }
    }
}

// MARK: AssetPriceChartInteractorInputProtocol

extension AssetPriceChartInteractor: AssetPriceChartInteractorInputProtocol {
    func updateSelectedCurrency(_ currency: Currency) {
        self.currency = currency

        fetchAndSubscribe()
    }

    func setup() {
        fetchAndSubscribe()
    }
}

// MARK: PriceLocalStorageSubscriber

extension AssetPriceChartInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {
        switch result {
        case let .success(priceData):
            presenter?.didReceive(price: priceData)
        case .failure:
            presenter?.didReceive(.priceDataNotAvailable)
        }
    }
}

enum AssetPriceChartInteractorError {
    case priceDataNotAvailable
    case missingPriceId
    case chartDataNotAvailable
}
