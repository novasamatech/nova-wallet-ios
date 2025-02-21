import Foundation
import SoraFoundation
import DGCharts

protocol AssetPriceChartViewModelFactoryProtocol {
    func createViewModel(
        for asset: AssetModel,
        entries: [PriceHistoryItem]?,
        availablePeriods: [PriceHistoryPeriod],
        selectedPeriod: PriceHistoryPeriod,
        priceData: PriceData?,
        locale: Locale
    ) -> AssetPriceChartWidgetViewModel

    func createPriceChangeViewModel(
        entries: [PriceHistoryItem]?,
        priceData: PriceData?,
        lastEntry: PriceHistoryItem,
        selectedPeriod: PriceHistoryPeriod,
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
        allEntries: [PriceHistoryItem],
        lastEntry: PriceHistoryItem,
        selectedPeriod: PriceHistoryPeriod,
        locale: Locale
    ) -> PricePeriodChangeViewModel {
        let firstEntry = allEntries.first ?? lastEntry

        let periodChangeDecimal = abs(lastEntry.value - firstEntry.value)

        let periodChangeAmountText = priceFormatter(priceId: priceData.currencyId)
            .value(for: locale)
            .stringFromDecimal(periodChangeDecimal) ?? ""

        let percentText = priceChangePercentFormatter
            .value(for: locale)
            .stringFromDecimal(periodChangeDecimal / firstEntry.value) ?? ""

        let finalText = periodChangeAmountText + "(\(percentText))"

        let changeType: PriceChangeType = if lastEntry.value >= firstEntry.value {
            .increase
        } else {
            .decrease
        }

        let changeDateText = createChangeDateText(
            for: lastEntry,
            allEntries: allEntries,
            selectedPeriod: selectedPeriod,
            locale: locale
        )

        return PricePeriodChangeViewModel(
            changeType: changeType,
            changeText: finalText,
            changeDateText: changeDateText
        )
    }

    func createChangeDateText(
        for lastEntry: PriceHistoryItem,
        allEntries: [PriceHistoryItem],
        selectedPeriod: PriceHistoryPeriod,
        locale: Locale
    ) -> String {
        let languages = locale.rLanguages

        let changeDateText: String

        if lastEntry.startedAt == allEntries.last?.startedAt {
            changeDateText = switch selectedPeriod {
            case .day: R.string.localizable.commonToday(preferredLanguages: languages)
            case .week: R.string.localizable.chartPeriodWeek(preferredLanguages: languages)
            case .month: R.string.localizable.chartPeriodMonth(preferredLanguages: languages)
            case .year: R.string.localizable.chartPeriodYear(preferredLanguages: languages)
            case .allTime: R.string.localizable.chartPeriodMax(preferredLanguages: languages)
            }
        } else {
            let date = Date(timeIntervalSince1970: TimeInterval(lastEntry.startedAt))
            let formatter = date.sameYear(as: Date())
                ? DateFormatter.chartEntryDate
                : DateFormatter.chartEntryWithYear
            changeDateText = formatter.value(for: locale).string(from: date)
        }

        return changeDateText
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
        entries: [PriceHistoryItem]?,
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
            let entries,
            let lastEntry = entries.last,
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

        let chartViewModel = createChartViewModel(using: entries)
        let changeViewModel = createPeriodChangeViewModel(
            priceData: priceData,
            allEntries: entries,
            lastEntry: lastEntry,
            selectedPeriod: selectedPeriod,
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
        entries: [PriceHistoryItem]?,
        priceData: PriceData?,
        lastEntry: PriceHistoryItem,
        selectedPeriod: PriceHistoryPeriod,
        locale: Locale
    ) -> PricePeriodChangeViewModel? {
        guard
            let priceData,
            let entries
        else { return nil }

        return createPeriodChangeViewModel(
            priceData: priceData,
            allEntries: entries,
            lastEntry: lastEntry,
            selectedPeriod: selectedPeriod,
            locale: locale
        )
    }
}
