import Foundation
import Foundation_iOS
import DGCharts

struct PriceChartWidgetFactoryParams {
    let asset: AssetModel?
    let entries: [PriceHistoryItem]?
    let availablePeriods: [PriceHistoryPeriod]
    let selectedPeriod: PriceHistoryPeriod
    let priceData: PriceData?
    let availablePoints: Int
    let placeholder: String?
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

        let signedPercent = createSignedPercent(
            percent: percent,
            percentText: percentText,
            changeType: changeType,
            locale: locale
        )

        let changeDateText = createChangeDateText(
            for: lastEntry,
            allEntries: allEntries,
            selectedPeriod: selectedPeriod,
            locale: locale
        )

        return PricePeriodChangeViewModel(
            changeType: changeType,
            changeText: finalText,
            percentText: signedPercent.text,
            percentChangeType: signedPercent.changeType,
            changeDateText: changeDateText
        )
    }

    func createSignedPercent(
        percent: Decimal,
        percentText: String,
        changeType: PriceChangeType,
        locale: Locale
    ) -> (text: String, changeType: PriceChangeType) {
        let displayedPercent = (percent as NSDecimalNumber).rounding(
            accordingToBehavior: Decimal.Rounding.down(scale: Constants.percentScale)
        )

        guard displayedPercent.decimalValue > 0 else {
            return (percentText, .increase)
        }

        let formatter = priceChangePercentFormatter.value(for: locale)
        let sign: String? = changeType == .increase ? formatter.plusSign : formatter.minusSign

        return ((sign ?? "") + percentText, changeType)
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
            case .day: R.string(preferredLanguages: languages).localizable.commonToday()
            case .week: R.string(preferredLanguages: languages).localizable.chartPeriodWeek()
            case .month: R.string(preferredLanguages: languages).localizable.chartPeriodMonth()
            case .year: R.string(preferredLanguages: languages).localizable.chartPeriodYear()
            case .allTime: R.string(preferredLanguages: languages).localizable.chartPeriodMax()
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
                R.string(preferredLanguages: languages).localizable.commonPeriod1d().uppercased()
            case .week:
                R.string(preferredLanguages: languages).localizable.commonPeriod7d().uppercased()
            case .month:
                R.string(preferredLanguages: languages).localizable.commonPeriod30d().uppercased()
            case .year:
                R.string(preferredLanguages: languages).localizable.commonPeriod1y().uppercased()
            case .allTime:
                R.string(preferredLanguages: languages).localizable.commonPeriodAll().capitalized(with: locale)
            }

            return PriceChartPeriodViewModel(period: $0, text: text)
        }

        let periodControlViewModel = PriceChartPeriodControlViewModel(
            periods: periods,
            selectedPeriodIndex: periods.firstIndex { $0.period == selectedPeriod } ?? 0
        )

        return periodControlViewModel
    }

    func createChartViewModel(
        using prices: [PriceHistoryItem],
        periodChange: PricePeriodChangeViewModel
    ) -> PriceChartViewModel {
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
            changeType: changeType,
            percentChangeType: periodChange.percentChangeType
        )
    }

    func optimizedEntries(
        from entries: [PriceHistoryItem]?,
        availablePoints: Int
    ) -> [PriceHistoryItem] {
        entries?.optimizedForChart(availablePoints: availablePoints) ?? []
    }

    func createCurrentPrice(
        priceData: PriceData?,
        locale: Locale
    ) -> LoadableViewModelState<String?> {
        guard
            let priceData,
            let priceDecimal = Decimal(string: priceData.price)
        else {
            return .loading
        }

        let priceText = priceFormatter(priceId: priceData.currencyId)
            .value(for: locale)
            .stringFromDecimal(priceDecimal)

        return .loaded(value: priceText)
    }
}

// MARK: AssetPriceChartViewModelFactoryProtocol

extension AssetPriceChartViewModelFactory: AssetPriceChartViewModelFactoryProtocol {
    func createViewModel(params: PriceChartWidgetFactoryParams) -> AssetPriceChartWidgetViewModel {
        let symbol = params.asset?.symbol ?? ""

        let title = [
            symbol,
            R.string(preferredLanguages: params.locale.rLanguages).localizable.commonPrice()
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

        let currentPrice = createCurrentPrice(
            priceData: params.priceData,
            locale: params.locale
        )

        guard
            let lastEntry = entries.last,
            let priceData = params.priceData,
            !currentPrice.isLoading
        else {
            return AssetPriceChartWidgetViewModel(
                title: title,
                symbol: symbol,
                currentPrice: currentPrice,
                periodChange: .loading,
                chartModel: .loading,
                periodControlModel: periodControlViewModel,
                placeholder: params.placeholder
            )
        }

        let changeViewModel = createPeriodChangeViewModel(
            priceData: priceData,
            allEntries: entries,
            lastEntry: lastEntry,
            selectedPeriod: params.selectedPeriod,
            locale: params.locale
        )
        let chartViewModel = createChartViewModel(using: entries, periodChange: changeViewModel)

        return AssetPriceChartWidgetViewModel(
            title: title,
            symbol: symbol,
            currentPrice: currentPrice,
            periodChange: .loaded(value: changeViewModel),
            chartModel: .loaded(value: chartViewModel),
            periodControlModel: periodControlViewModel,
            placeholder: params.placeholder
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

private extension AssetPriceChartViewModelFactory {
    enum Constants {
        static let percentScale: Int32 = 4
    }
}
