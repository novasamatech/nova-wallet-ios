import Foundation
import SoraFoundation
import DGCharts

protocol AssetPriceChartViewModelFactoryProtocol {
    func createViewModel(
        for asset: AssetModel,
        prices: [CoingeckoChartSinglePriceData],
        availablePeriods: [PriceChartPeriod],
        selectedPeriod: PriceChartPeriod,
        priceData: PriceData?,
        locale: Locale
    ) -> AssetPriceChartWidgetViewModel

    func createPriceChangeViewModel(
        prices: [CoingeckoChartSinglePriceData],
        priceData: PriceData?,
        closingPrice: Decimal,
        locale: Locale
    ) -> PricePeriodChangeViewModel?
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

// MARK: Private

private extension AssetPriceChartViewModelFactory {
    func priceFormatter(priceId: Int?) -> LocalizableResource<TokenFormatter> {
        let assetBalanceDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: priceId)
        return assetBalanceFormatterFactory.createAssetPriceFormatter(for: assetBalanceDisplayInfo)
    }

    func formattedPrice(
        for priceData: PriceData,
        _ locale: Locale
    ) -> String? {
        let priceDecimal = Decimal(string: priceData.price) ?? 0.0

        let price = priceFormatter(priceId: priceData.currencyId)
            .value(for: locale)
            .stringFromDecimal(priceDecimal)

        return price
    }

    func createPeriodChangeViewModel(
        priceData: PriceData,
        firstPrice: Decimal,
        lastPrice: Decimal,
        locale: Locale
    ) -> PricePeriodChangeViewModel {
        let periodChangeDecimal = abs(lastPrice - firstPrice)

        let periodChangeAmountText = priceFormatter(priceId: priceData.currencyId)
            .value(for: locale)
            .stringFromDecimal(periodChangeDecimal) ?? ""

        let percentText = priceChangePercentFormatter
            .value(for: locale)
            .stringFromDecimal(periodChangeDecimal / firstPrice) ?? ""

        let finalText = periodChangeAmountText + "(\(percentText))"

        let changeViewModel: PricePeriodChangeViewModel = if lastPrice >= firstPrice {
            .increase(finalText)
        } else {
            .decrease(finalText)
        }

        return changeViewModel
    }

    func createPeriodsControlViewModel(
        availablePeriods: [PriceChartPeriod],
        selectedPeriod: PriceChartPeriod
    ) -> PriceChartPeriodControlViewModel {
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

        return periodControlViewModel
    }

    func createChartViewModel(using prices: [CoingeckoChartSinglePriceData]) -> PriceChartViewModel {
        let dataSet = prices.map { price in
            ChartDataEntry(
                x: Double(price.timeStamp),
                y: (price.price as NSDecimalNumber).doubleValue
            )
        }

        return PriceChartViewModel(dataSet: dataSet)
    }
}

// MARK: AssetPriceChartViewModelFactoryProtocol

extension AssetPriceChartViewModelFactory: AssetPriceChartViewModelFactoryProtocol {
    func createViewModel(
        for asset: AssetModel,
        prices: [CoingeckoChartSinglePriceData],
        availablePeriods: [PriceChartPeriod],
        selectedPeriod: PriceChartPeriod,
        priceData: PriceData?,
        locale: Locale
    ) -> AssetPriceChartWidgetViewModel {
        let title = [
            asset.symbol,
            R.string.localizable.commonPrice(preferredLanguages: locale.rLanguages)
        ].joined(with: .space)

        let periodControlViewModel = createPeriodsControlViewModel(
            availablePeriods: availablePeriods,
            selectedPeriod: selectedPeriod
        )

        guard
            let firstPrice = prices.first,
            let lastPrice = prices.last,
            let priceData
        else {
            return AssetPriceChartWidgetViewModel(
                title: title,
                currentPrice: .loading,
                periodChange: .loading,
                chartModel: .loading,
                periodControlModel: periodControlViewModel
            )
        }

        let chartViewModel = createChartViewModel(using: prices)
        let changeViewModel = createPeriodChangeViewModel(
            priceData: priceData,
            firstPrice: firstPrice.price,
            lastPrice: lastPrice.price,
            locale: locale
        )
        let currentPrice = formattedPrice(for: priceData, locale)

        return AssetPriceChartWidgetViewModel(
            title: title,
            currentPrice: .loaded(value: currentPrice),
            periodChange: .loaded(value: changeViewModel),
            chartModel: .loaded(value: chartViewModel),
            periodControlModel: periodControlViewModel
        )
    }

    func createPriceChangeViewModel(
        prices: [CoingeckoChartSinglePriceData],
        priceData: PriceData?,
        closingPrice: Decimal,
        locale: Locale
    ) -> PricePeriodChangeViewModel? {
        guard
            let priceData,
            let firstPrice = prices.first
        else { return nil }

        return createPeriodChangeViewModel(
            priceData: priceData,
            firstPrice: firstPrice.price,
            lastPrice: closingPrice,
            locale: locale
        )
    }
}

struct CoingeckoChartSinglePriceData {
    let timeStamp: Int64
    let price: Decimal
}
