import Foundation
import Operation_iOS

protocol SubtensorPriceSeriesProviding: AnyObject {
    func createSeriesWrapper(
        for priceId: AssetModel.PriceId,
        currency: Currency,
        period: PriceHistoryPeriod
    ) -> CompoundOperationWrapper<PriceHistory>

    func expirationDate(for priceId: AssetModel.PriceId, currency: Currency, period: PriceHistoryPeriod) -> Date?
}

final class SubtensorPriceSeriesCache {
    let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol

    private let store: HTTPResponseCacheStore<Key, PriceHistory>

    init(
        coingeckoOperationFactory: CoingeckoOperationFactoryProtocol,
        operationQueue: OperationQueue,
        timeProvider: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 }
    ) {
        self.coingeckoOperationFactory = coingeckoOperationFactory

        store = HTTPResponseCacheStore(operationQueue: operationQueue, timeProvider: timeProvider)
    }
}

private extension SubtensorPriceSeriesCache {
    struct Key: Hashable {
        let priceId: AssetModel.PriceId
        let currencyId: Int
        let period: PriceHistoryPeriod
    }
}

extension SubtensorPriceSeriesCache: SubtensorPriceSeriesProviding {
    func createSeriesWrapper(
        for priceId: AssetModel.PriceId,
        currency: Currency,
        period: PriceHistoryPeriod
    ) -> CompoundOperationWrapper<PriceHistory> {
        let key = Key(priceId: priceId, currencyId: currency.id, period: period)
        let waiterId = UUID()
        let store = store
        let coingeckoOperationFactory = coingeckoOperationFactory

        let operation = AsyncClosureOperation<PriceHistory>(
            operationClosure: { completion in
                store.request(
                    key,
                    waiterId: waiterId,
                    fetch: {
                        CompoundOperationWrapper(
                            targetOperation: coingeckoOperationFactory.fetchCacheablePriceHistory(
                                for: priceId,
                                currency: currency,
                                period: period
                            )
                        )
                    },
                    completion: { result in
                        completion(result.map(\.value))
                    }
                )
            },
            cancelationClosure: {
                store.removeWaiter(waiterId, for: key)
            }
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func expirationDate(for priceId: AssetModel.PriceId, currency: Currency, period: PriceHistoryPeriod) -> Date? {
        let key = Key(priceId: priceId, currencyId: currency.id, period: period)

        guard case let .fresh(_, freshUntil) = store.peek(key) else {
            return nil
        }

        return Date(timeIntervalSince1970: freshUntil)
    }
}
