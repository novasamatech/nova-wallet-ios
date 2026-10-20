import Foundation

enum AnalyticsCrossRateFactory {
    static func createProvider() -> AnalyticsCrossRateProviding {
        guard !EnviromentVariables.isUnitTesting else {
            return AnalyticsIdentityCrossRateProvider()
        }

        return sharedStore
    }

    static func createUpdater() -> AnalyticsCrossRateUpdating? {
        guard !EnviromentVariables.isUnitTesting else {
            return nil
        }

        return sharedStore
    }

    private static let sharedStore = AnalyticsCrossRateStore()
}

struct AnalyticsIdentityCrossRateProvider: AnalyticsCrossRateProviding {
    func normalisedRate(for priceData: PriceData) -> Decimal? {
        priceData.decimalRate
    }
}
