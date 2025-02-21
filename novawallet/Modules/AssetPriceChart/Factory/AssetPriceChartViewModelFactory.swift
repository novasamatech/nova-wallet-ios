import Foundation
import SoraFoundation
import DGCharts

protocol AssetPriceChartViewModelFactoryProtocol {
    func createViewModel(
        for asset: AssetModel,
        prices: [PriceHistoryItem]?,
        availablePeriods: [PriceHistoryPeriod],
        selectedPeriod: PriceHistoryPeriod,
        priceData: PriceData?,
        locale: Locale
    ) -> AssetPriceChartWidgetViewModel

    func createPriceChangeViewModel(
        prices: [PriceHistoryItem]?,
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

        let changeType: PriceChangeType = if lastPrice >= firstPrice {
            .increase
        } else {
            .decrease
        }

        return PricePeriodChangeViewModel(
            changeType: changeType,
            text: finalText
        )
    }

    func createPeriodsControlViewModel(
        availablePeriods: [PriceHistoryPeriod],
        selectedPeriod: PriceHistoryPeriod
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

    func createChartViewModel(using prices: [PriceHistoryItem]) -> PriceChartViewModel {
        let firstPrice = prices.first?.value ?? 0.0
        let lastPrice = prices.last?.value ?? 0.0

        let dataSet = prices.map { price in
            ChartDataEntry(
                x: Double(price.startedAt),
                y: (price.value as NSDecimalNumber).doubleValue
            )
        }

        let changeType: PriceChangeType = lastPrice >= firstPrice ? .increase : .decrease

        return PriceChartViewModel(
            dataSet: dataSet,
            changeType: changeType
        )
    }
}

// MARK: AssetPriceChartViewModelFactoryProtocol

extension AssetPriceChartViewModelFactory: AssetPriceChartViewModelFactoryProtocol {
    func createViewModel(
        for asset: AssetModel,
        prices: [PriceHistoryItem]?,
        availablePeriods: [PriceHistoryPeriod],
        selectedPeriod: PriceHistoryPeriod,
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
            let prices,
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
            firstPrice: firstPrice.value,
            lastPrice: lastPrice.value,
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
        prices: [PriceHistoryItem]?,
        priceData: PriceData?,
        closingPrice: Decimal,
        locale: Locale
    ) -> PricePeriodChangeViewModel? {
        guard
            let priceData,
            let firstPrice = prices?.first
        else { return nil }

        return createPeriodChangeViewModel(
            priceData: priceData,
            firstPrice: firstPrice.value,
            lastPrice: closingPrice,
            locale: locale
        )
    }
}
