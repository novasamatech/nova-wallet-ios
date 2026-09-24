import Foundation

enum AnalyticsCrossRateFactory {
    static func createProvider() -> AnalyticsCrossRateProviding {
        guard !isUnitTesting else {
            return AnalyticsIdentityCrossRateProvider()
        }

        return sharedStore
    }

    static func createUpdater() -> AnalyticsCrossRateUpdating? {
        guard !isUnitTesting else {
            return nil
        }

        return sharedStore
    }

    private enum Constants {
        static let unitTestArgument = "-UNITTEST"
    }

    private static let isUnitTesting = ProcessInfo.processInfo.arguments
        .contains(Constants.unitTestArgument)

    private static let sharedStore = AnalyticsCrossRateStore()
}

struct AnalyticsIdentityCrossRateProvider: AnalyticsCrossRateProviding {
    func normalisedRate(for priceData: PriceData) -> Decimal? {
        priceData.decimalRate
    }
}
