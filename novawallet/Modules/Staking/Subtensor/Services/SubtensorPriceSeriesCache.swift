import Foundation
import Operation_iOS

protocol SubtensorPriceSeriesProviding: AnyObject {
    func createSeriesWrapper(
        for priceId: AssetModel.PriceId,
        currency: Currency,
        period: PriceHistoryPeriod
    ) -> CompoundOperationWrapper<PriceHistory>
}

final class SubtensorPriceSeriesCache {
    let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol

    private let mutex = NSLock()
    private var entries: [Key: (value: PriceHistory, freshUntil: TimeInterval)] = [:]

    init(coingeckoOperationFactory: CoingeckoOperationFactoryProtocol) {
        self.coingeckoOperationFactory = coingeckoOperationFactory
    }
}

private extension SubtensorPriceSeriesCache {
    struct Key: Hashable {
        let priceId: AssetModel.PriceId
        let currencyId: Int
        let period: PriceHistoryPeriod
    }

    func freshValue(for key: Key, at now: TimeInterval) -> PriceHistory? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let entry = entries[key], now < entry.freshUntil else {
            return nil
        }

        return entry.value
    }

    func store(_ value: PriceHistory, for key: Key, freshUntil: TimeInterval) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        entries[key] = (value, freshUntil)
    }
}

extension SubtensorPriceSeriesCache: SubtensorPriceSeriesProviding {
    func createSeriesWrapper(
        for priceId: AssetModel.PriceId,
        currency: Currency,
        period: PriceHistoryPeriod
    ) -> CompoundOperationWrapper<PriceHistory> {
        let key = Key(priceId: priceId, currencyId: currency.id, period: period)
        let fetchStartedAt = Date().timeIntervalSince1970

        if let value = freshValue(for: key, at: fetchStartedAt) {
            return .createWithResult(value)
        }

        let fetchOperation = coingeckoOperationFactory.fetchCacheablePriceHistory(
            for: priceId,
            currency: currency,
            period: period
        )

        let storeOperation = ClosureOperation<PriceHistory> { [weak self] in
            let (value, directives) = try fetchOperation.extractNoCancellableResultData()

            if case let .reusable(lifetime) = directives {
                self?.store(value, for: key, freshUntil: fetchStartedAt + lifetime)
            }

            return value
        }

        storeOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: storeOperation, dependencies: [fetchOperation])
    }
}
