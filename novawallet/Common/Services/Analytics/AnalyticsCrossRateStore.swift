import Foundation

protocol AnalyticsCrossRateProviding {
    func normalisedRate(for priceData: PriceData) -> Decimal?
}

protocol AnalyticsCrossRateUpdating: AnyObject {
    func save(usdPerUnit: Decimal, for currency: Currency)
}

final class AnalyticsCrossRateStore {
    private let cache: InMemoryCache<Int, Decimal>

    init() {
        cache = InMemoryCache(with: [Currency.usd.id: 1])
    }
}

// MARK: - AnalyticsCrossRateProviding

extension AnalyticsCrossRateStore: AnalyticsCrossRateProviding {
    func normalisedRate(for priceData: PriceData) -> Decimal? {
        guard
            let currencyId = priceData.currencyId,
            let displayRate = priceData.decimalRate,
            let usdPerUnit = cache.fetchValue(for: currencyId)
        else {
            return nil
        }

        let normalisedRate = displayRate * usdPerUnit

        guard !normalisedRate.isNaN else {
            return nil
        }

        return normalisedRate
    }
}

// MARK: - AnalyticsCrossRateUpdating

extension AnalyticsCrossRateStore: AnalyticsCrossRateUpdating {
    func save(usdPerUnit: Decimal, for currency: Currency) {
        guard !usdPerUnit.isNaN, usdPerUnit > 0 else {
            return
        }

        cache.store(value: usdPerUnit, for: currency.id)
    }
}
