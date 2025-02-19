import Foundation
import DGCharts

protocol AssetPriceChartViewModelFactoryProtocol {
    func createViewModel(
        for asset: AssetModel,
        locale: Locale
    ) -> AssetPriceChartWidgetViewModel
}

final class AssetPriceChartViewModelFactory {}

// MARK: AssetPriceChartViewModelFactoryProtocol

extension AssetPriceChartViewModelFactory: AssetPriceChartViewModelFactoryProtocol {
    func createViewModel(
        for asset: AssetModel,
        locale: Locale
    ) -> AssetPriceChartWidgetViewModel {
        let title = [
            asset.symbol,
            R.string.localizable.commonPrice(preferredLanguages: locale.rLanguages)
        ].joined(with: .space)

        let dataSet = prices.map { price in
            ChartDataEntry(
                x: Double(price.timeStamp),
                y: (price.price as NSDecimalNumber).doubleValue
            )
        }
        let chartViewModel = PriceChartViewModel(dataSet: dataSet)

        let periods: [PriceChartPeriodViewModel] = [
            .day("1D"),
            .week("1W"),
            .month("1M"),
            .year("1Y")
        ]
        let periodControlViewModel = PriceChartPeriodControlViewModel(periods: periods)

        return AssetPriceChartWidgetViewModel(
            title: title,
            currentPrice: "\(prices.last!.price)",
            periodChange: .up("3.45%"),
            chartModel: chartViewModel,
            periodControlModel: periodControlViewModel
        )
    }
}

// STUB

private let prices: [CoingeckoChartSinglePriceData] = [
    CoingeckoChartSinglePriceData(timeStamp: 1_711_843_200_000, price: 69702.3087473573),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_846_800_000, price: 70123.4521684291),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_850_400_000, price: 69892.1845762934),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_854_000_000, price: 70356.2947583621),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_857_600_000, price: 70245.8374629158),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_861_200_000, price: 70892.4563781245),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_864_800_000, price: 71234.5678912345),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_868_400_000, price: 71123.4567891234),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_872_000_000, price: 70987.6543210987),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_875_600_000, price: 71345.6789123456),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_879_200_000, price: 71567.8901234567),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_882_800_000, price: 71789.0123456789),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_886_400_000, price: 71654.3210987654),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_890_000_000, price: 71432.1098765432),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_893_600_000, price: 71876.5432109876),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_897_200_000, price: 72098.7654321098),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_900_800_000, price: 72345.6789123456),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_904_400_000, price: 72123.4567891234),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_908_000_000, price: 72456.7890123456),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_911_600_000, price: 72678.9012345678),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_915_200_000, price: 72901.2345678901),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_918_800_000, price: 72789.0123456789),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_922_400_000, price: 73012.3456789012),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_926_000_000, price: 73234.5678901234),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_929_600_000, price: 73456.7890123456),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_933_200_000, price: 73234.5678901234),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_936_800_000, price: 73567.8901234567),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_940_400_000, price: 73789.0123456789),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_944_000_000, price: 73567.8901234567),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_947_600_000, price: 73890.1234567890),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_951_200_000, price: 74123.4567890123),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_954_800_000, price: 74345.6789012345),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_958_400_000, price: 74567.8901234567),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_962_000_000, price: 74789.0123456789),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_965_600_000, price: 74567.8901234567),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_969_200_000, price: 74890.1234567890),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_972_800_000, price: 75123.4567890123),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_976_400_000, price: 75345.6789012345),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_980_000_000, price: 75123.4567890123),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_983_600_000, price: 75456.7890123456),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_987_200_000, price: 75678.9012345678),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_990_800_000, price: 75901.2345678901),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_994_400_000, price: 75789.0123456789),
    CoingeckoChartSinglePriceData(timeStamp: 1_711_998_000_000, price: 76012.3456789012),
    CoingeckoChartSinglePriceData(timeStamp: 1_712_001_600_000, price: 76234.5678901234),
    CoingeckoChartSinglePriceData(timeStamp: 1_712_005_200_000, price: 76456.7890123456),
    CoingeckoChartSinglePriceData(timeStamp: 1_712_008_800_000, price: 76234.5678901234),
    CoingeckoChartSinglePriceData(timeStamp: 1_712_012_400_000, price: 76567.8901234567),
    CoingeckoChartSinglePriceData(timeStamp: 1_712_016_000_000, price: 76789.0123456789),
    CoingeckoChartSinglePriceData(timeStamp: 1_712_019_600_000, price: 76567.8901234567)
]

private struct CoingeckoChartSinglePriceData {
    let timeStamp: Int64
    let price: Decimal
}
