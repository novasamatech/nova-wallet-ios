import Foundation_iOS
@testable import novawallet
import XCTest

enum SubtensorPriceChartTestHelper {
    static let end = Date(timeIntervalSince1970: 1_791_979_200)
    static let day: TimeInterval = 86400
    static let locale = Locale(identifier: "en")

    static func point(daysBefore: Double, value: Decimal, end: Date = end) -> SubtensorPricePoint {
        SubtensorPricePoint(date: end.addingTimeInterval(-daysBefore * day), taoPerAlpha: value, fiatPerAlpha: value * 10)
    }

    static func history(
        points: [SubtensorPricePoint]? = nil,
        period: SubtensorPricePeriod = .week,
        change: Decimal? = nil
    ) -> SubtensorPriceHistory {
        SubtensorPriceHistory(
            subnet: SubtensorSubnetRef(netuid: 64, registeredAt: 0),
            period: period,
            points: points ?? [point(daysBefore: 3, value: 3), point(daysBefore: 1, value: 2), point(daysBefore: 0, value: 1)],
            changeInTao: change,
            changeInFiat: change
        )
    }

    static func factory() -> SubtensorPriceWidgetViewModelFactory {
        SubtensorPriceWidgetViewModelFactory(
            chainAsset: SubtensorFlowChainWorld.chainAsset(),
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
        )
    }

    static func params(
        history: SubtensorPriceHistory = history(),
        period: SubtensorPricePeriod = .week,
        end: Date = end,
        isFiat: Bool = false,
        selection: SubtensorPriceChartSelection? = nil
    ) -> SubtensorPriceWidgetParams {
        SubtensorPriceWidgetParams(
            caption: "Price",
            spotPrice: 999,
            history: .available(history),
            period: period,
            isFiat: isFiat,
            taoPrice: nil,
            currencyId: Currency.usd.id,
            currency: nil,
            chartEndDate: end,
            selection: selection
        )
    }

    static func chart(_ widget: SubtensorPriceWidgetViewModel) throws -> SubtensorPriceChartViewModel {
        guard case let .chart(chart) = widget.chart else {
            throw TestError.chartUnavailable
        }
        return chart
    }

    static func series(_ chart: SubtensorPriceChartViewModel) throws -> SubtensorPriceChartViewModel.DatedSeries {
        guard case let .dated(series) = chart.series else {
            throw TestError.expectedDatedSeries
        }
        return series
    }

    private enum TestError: Error {
        case chartUnavailable
        case expectedDatedSeries
    }
}
