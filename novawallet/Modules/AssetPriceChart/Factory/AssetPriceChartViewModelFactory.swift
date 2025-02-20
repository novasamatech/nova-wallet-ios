import Foundation
import SoraFoundation
import DGCharts

protocol AssetPriceChartViewModelFactoryProtocol {
    func createViewModel(
        prices: [CoingeckoChartSinglePriceData],
        availablePeriods: [PriceChartPeriod],
        selectedPeriod: PriceChartPeriod,
        for asset: AssetModel,
        locale: Locale
    ) -> LoadableViewModelState<AssetPriceChartWidgetViewModel>
}

final class AssetPriceChartViewModelFactory {
    let priceChangePercentFormatter: LocalizableResource<NumberFormatter>
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol

    init(
        priceChangePercentFormatter: LocalizableResource<NumberFormatter>,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) {
        self.priceChangePercentFormatter = priceChangePercentFormatter
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.priceAssetInfoFactory = priceAssetInfoFactory
    }
}

// MARK: AssetPriceChartViewModelFactoryProtocol

extension AssetPriceChartViewModelFactory: AssetPriceChartViewModelFactoryProtocol {
    func createViewModel(
        prices: [CoingeckoChartSinglePriceData],
        availablePeriods: [PriceChartPeriod],
        selectedPeriod: PriceChartPeriod,
        for asset: AssetModel,
        locale: Locale
    ) -> LoadableViewModelState<AssetPriceChartWidgetViewModel> {
        guard
            let firstPrice = prices.first,
            let lastPrice = prices.last
        else { return .loading }

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

        let periods: [PriceChartPeriodViewModel] = availablePeriods.map {
            let text = switch $0 {
            case .day: "1D"
            case .week: "1W"
            case .month: "1M"
            case .year: "1Y"
            case .allTime: "All"
            }

            return PriceChartPeriodViewModel(period: $0, text: text)
        }

        let periodControlViewModel = PriceChartPeriodControlViewModel(
            periods: periods,
            selectedPeriodIndex: periods.firstIndex { $0.period == selectedPeriod } ?? 0
        )

        let periodChangeDecimal = lastPrice.price - firstPrice.price
        let periodChangePercent = abs(periodChangeDecimal / firstPrice.price * 100)
        let periodChangeText = String(format: "%.2f", periodChangePercent as CVarArg)

        let changeViewModel: PricePeriodChangeViewModel = if periodChangeDecimal >= 0 {
            .up(periodChangeText)
        } else {
            .down(periodChangeText)
        }

        let viewModel = AssetPriceChartWidgetViewModel(
            title: title,
            currentPrice: "\(prices.last!.price)",
            periodChange: changeViewModel,
            chartModel: chartViewModel,
            periodControlModel: periodControlViewModel
        )

        return .loaded(value: viewModel)
    }
}

struct CoingeckoChartSinglePriceData {
    let timeStamp: Int64
    let price: Decimal
}
