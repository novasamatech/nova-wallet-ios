import Foundation

extension PriceData {
    var analyticsRate: Decimal? {
        AnalyticsCrossRateFactory.createProvider().normalisedRate(for: self)
    }
}
