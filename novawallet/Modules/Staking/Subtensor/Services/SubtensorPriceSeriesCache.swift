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
    let operationQueue: OperationQueue
    let timeProvider: () -> Date

    private let mutex = NSLock()
    private var entries: [Key: Entry] = [:]
    private var fetches: [Key: Fetch] = [:]

    init(
        coingeckoOperationFactory: CoingeckoOperationFactoryProtocol,
        operationQueue: OperationQueue,
        timeProvider: @escaping () -> Date = { Date() }
    ) {
        self.coingeckoOperationFactory = coingeckoOperationFactory
        self.operationQueue = operationQueue
        self.timeProvider = timeProvider
    }

    static func timeToLive(for period: PriceHistoryPeriod) -> TimeInterval {
        switch period {
        case .day:
            return TimeInterval(5).secondsFromMinutes
        case .week, .month:
            return TimeInterval(1).secondsFromHours
        case .year, .allTime:
            return TimeInterval(1).secondsFromDays
        }
    }

    deinit {
        fetches.values.forEach { fetch in
            fetch.operation.cancel()
            fetch.completions.forEach { $0(.failure(BaseOperationError.parentOperationCancelled)) }
        }
    }
}

private extension SubtensorPriceSeriesCache {
    struct Key: Hashable {
        let priceId: AssetModel.PriceId
        let currencyId: Int
        let period: PriceHistoryPeriod
    }

    struct Entry {
        let history: PriceHistory
        let expiresAt: Date
    }

    struct Fetch {
        let operation: BaseOperation<PriceHistory>
        var completions: [(Result<PriceHistory, Error>) -> Void]
    }

    func isFresh(_ entry: Entry, at now: Date) -> Bool {
        now < entry.expiresAt
    }

    func requestSeries(
        for key: Key,
        currency: Currency,
        completion: @escaping (Result<PriceHistory, Error>) -> Void
    ) {
        mutex.lock()

        if let entry = entries[key], isFresh(entry, at: timeProvider()) {
            mutex.unlock()
            completion(.success(entry.history))
            return
        }

        guard fetches[key] == nil else {
            fetches[key]?.completions.append(completion)
            mutex.unlock()
            return
        }

        let operation = coingeckoOperationFactory.fetchPriceHistory(
            for: key.priceId,
            currency: currency,
            period: key.period
        )

        fetches[key] = Fetch(operation: operation, completions: [completion])

        mutex.unlock()

        operation.completionBlock = { [weak self, weak operation] in
            self?.completeSeries(for: key, result: operation?.result)
        }

        operationQueue.addOperation(operation)
    }

    func completeSeries(for key: Key, result: Result<PriceHistory, Error>?) {
        mutex.lock()

        let completions = fetches.removeValue(forKey: key)?.completions ?? []
        let now = timeProvider()

        entries = entries.filter { isFresh($0.value, at: now) }

        if case let .success(history) = result {
            entries[key] = Entry(history: history, expiresAt: now.addingTimeInterval(Self.timeToLive(for: key.period)))
        }

        mutex.unlock()

        let finalResult = result ?? .failure(BaseOperationError.parentOperationCancelled)

        completions.forEach { $0(finalResult) }
    }
}

extension SubtensorPriceSeriesCache: SubtensorPriceSeriesProviding {
    func createSeriesWrapper(
        for priceId: AssetModel.PriceId,
        currency: Currency,
        period: PriceHistoryPeriod
    ) -> CompoundOperationWrapper<PriceHistory> {
        let key = Key(priceId: priceId, currencyId: currency.id, period: period)

        let operation = AsyncClosureOperation<PriceHistory> { [weak self] completion in
            guard let self else {
                completion(.failure(BaseOperationError.parentOperationCancelled))
                return
            }

            requestSeries(for: key, currency: currency, completion: completion)
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func expirationDate(for priceId: AssetModel.PriceId, currency: Currency, period: PriceHistoryPeriod) -> Date? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return entries[Key(priceId: priceId, currencyId: currency.id, period: period)]?.expiresAt
    }
}
