import Foundation

protocol SubtensorPriceHistoryCaching: AnyObject {
    func history(
        for subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        currency: Currency
    ) -> SubtensorPriceHistoryResult?

    func store(
        _ entry: SubtensorPriceHistoryEntry,
        for subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        currency: Currency
    )
}

final class SubtensorPriceHistoryCache {
    private let mutex = NSLock()
    private var entries: [Key: SubtensorPriceHistoryEntry] = [:]
}

private extension SubtensorPriceHistoryCache {
    struct Key: Hashable {
        let subnet: SubtensorSubnetRef
        let period: SubtensorPricePeriod
        let currencyId: Int
    }
}

extension SubtensorPriceHistoryCache: SubtensorPriceHistoryCaching {
    func history(
        for subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        currency: Currency
    ) -> SubtensorPriceHistoryResult? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let key = Key(subnet: subnet, period: period, currencyId: currency.id)

        guard let entry = entries[key], Date() < entry.expiresAt else {
            entries[key] = nil
            return nil
        }

        return entry.result
    }

    func store(
        _ entry: SubtensorPriceHistoryEntry,
        for subnet: SubtensorSubnetRef,
        period: SubtensorPricePeriod,
        currency: Currency
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let now = Date()

        entries = entries.filter { now < $0.value.expiresAt }
        entries[Key(subnet: subnet, period: period, currencyId: currency.id)] = entry
    }
}
