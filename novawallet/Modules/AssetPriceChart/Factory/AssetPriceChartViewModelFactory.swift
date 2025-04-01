import Foundation
import Foundation_iOS
import DGCharts

struct PriceChartWidgetFactoryParams {
    let asset: AssetModel
    let entries: [PriceHistoryItem]?
    let availablePeriods: [PriceHistoryPeriod]
    let selectedPeriod: PriceHistoryPeriod
    let priceData: PriceData?
    let availablePoints: Int
    let locale: Locale
}

struct PriceChartPriceUpdateViewFactoryParams {
    let entries: [PriceHistoryItem]?
    let priceData: PriceData?
    let lastEntry: PriceHistoryItem
    let selectedPeriod: PriceHistoryPeriod
    let locale: Locale
}

protocol AssetPriceChartViewModelFactoryProtocol {
    func createViewModel(params: PriceChartWidgetFactoryParams) -> AssetPriceChartWidgetViewModel
    func createPriceUpdateViewModel(
        params: PriceChartPriceUpdateViewFactoryParams
    ) -> AssetPriceChartPriceUpdateViewModel?
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

        let percent = if firstEntry.value > 0 {
            periodChangeDecimal / firstEntry.value
        } else {
            periodChangeDecimal
        }

        let percentText = priceChangePercentFormatter
            .value(for: locale)
            .stringFromDecimal(percent) ?? ""

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
        locale: Locale,
        availablePeriods: [PriceHistoryPeriod],
        selectedPeriod: PriceHistoryPeriod
    ) -> PriceChartPeriodControlViewModel {
        let languages = locale.rLanguages

        let periods: [PriceChartPeriodViewModel] = availablePeriods.map {
            let text = switch $0 {
            case .day:
                R.string.localizable.commonPeriod1d(preferredLanguages: languages).uppercased()
            case .week:
                R.string.localizable.commonPeriod7d(preferredLanguages: languages).uppercased()
            case .month:
                R.string.localizable.commonPeriod30d(preferredLanguages: languages).uppercased()
            case .year:
                R.string.localizable.commonPeriod1y(preferredLanguages: languages).uppercased()
            case .allTime:
                R.string.localizable.commonPeriodAll(preferredLanguages: languages).capitalized(with: locale)
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

    func optimizedEntries(
        from entries: [PriceHistoryItem]?,
        availablePoints: Int
    ) -> [PriceHistoryItem] {
        guard let entries else { return [] }

        if entries.count > availablePoints {
            var mutableEntries = entries
            let firstEntry = mutableEntries.removeFirst()
            let lastEntry = mutableEntries.removeLast()

            let filteredEntries = mutableEntries
                .distributed(intoChunks: availablePoints - 2)
                .compactMap(\.first)

            return [firstEntry] + filteredEntries + [lastEntry]
        } else {
            return entries
        }
    }
}

// MARK: AssetPriceChartViewModelFactoryProtocol

extension AssetPriceChartViewModelFactory: AssetPriceChartViewModelFactoryProtocol {
    func createViewModel(params: PriceChartWidgetFactoryParams) -> AssetPriceChartWidgetViewModel {
        let title = [
            params.asset.symbol,
            R.string.localizable.commonPrice(preferredLanguages: params.locale.rLanguages)
        ].joined(with: .space)

        let periodControlViewModel = createPeriodsControlViewModel(
            locale: params.locale,
            availablePeriods: params.availablePeriods,
            selectedPeriod: params.selectedPeriod
        )

        let entries = optimizedEntries(
            from: params.entries,
            availablePoints: params.availablePoints
        )

        guard
            let lastEntry = entries.last,
            let priceData = params.priceData,
            let priceDecimal = Decimal(string: priceData.price)
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
            selectedPeriod: params.selectedPeriod,
            locale: params.locale
        )

        let currentPrice = priceFormatter(priceId: priceData.currencyId)
            .value(for: params.locale)
            .stringFromDecimal(priceDecimal)

        return AssetPriceChartWidgetViewModel(
            title: title,
            currentPrice: .loaded(value: currentPrice),
            periodChange: .loaded(value: changeViewModel),
            chartModel: .loaded(value: chartViewModel),
            periodControlModel: periodControlViewModel
        )
    }

    func createPriceUpdateViewModel(
        params: PriceChartPriceUpdateViewFactoryParams
    ) -> AssetPriceChartPriceUpdateViewModel? {
        guard
            let priceData = params.priceData,
            let entries = params.entries
        else { return nil }

        let changeViewModel = createPeriodChangeViewModel(
            priceData: priceData,
            allEntries: entries,
            lastEntry: params.lastEntry,
            selectedPeriod: params.selectedPeriod,
            locale: params.locale
        )

        let priceText = priceFormatter(priceId: priceData.currencyId)
            .value(for: params.locale)
            .stringFromDecimal(params.lastEntry.value)

        return AssetPriceChartPriceUpdateViewModel(
            currentPrice: priceText,
            changeViewModel: changeViewModel
        )
    }
}
