import Foundation
import Foundation_iOS

struct SubtensorPriceWidgetParams {
    let caption: String
    let spotPrice: Decimal?
    var history: SubtensorSubnetHistoryState
    let period: SubtensorPricePeriod
    let isFiat: Bool
    let taoPrice: PriceData?
    let currencyId: Int?
    let currency: SubtensorSubnetCurrencyViewModel?
    let selectedPoint: Int?
}

protocol SubtensorPriceWidgetFactoryProtocol {
    func createCaption(
        subnetTitle: String,
        stamps: [SubtensorBackendStamp],
        now: Date,
        locale: Locale
    ) -> String

    func createWidget(
        for params: SubtensorPriceWidgetParams,
        locale: Locale
    ) -> SubtensorPriceWidgetViewModel

    func createHeader(
        for params: SubtensorPriceWidgetParams,
        locale: Locale
    ) -> SubtensorSubnetPriceHeaderViewModel
}

final class SubtensorPriceWidgetViewModelFactory {
    static let periods: [SubtensorPricePeriod] = [.day, .week, .month, .quarter, .year]
    static let defaultPeriod = SubtensorPricePeriod.week

    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let formatterFactory: AssetBalanceFormatterFactoryProtocol
    let tokenFormatter: LocalizableResource<TokenFormatter>
    let axisFormatter: LocalizableResource<LocalizableDecimalFormatting>
    let balanceViewModelFactory: PrimitiveBalanceViewModelFactoryProtocol

    init(
        chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) {
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.formatterFactory = formatterFactory

        let taoInfo = chainAsset.assetDisplayInfo

        tokenFormatter = formatterFactory.createTokenFormatter(for: taoInfo)
        axisFormatter = formatterFactory.createDisplayFormatter(for: taoInfo)
        balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: taoInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
    }
}

private extension SubtensorPriceWidgetViewModelFactory {
    struct SeriesPoint {
        let date: Date
        let value: Decimal

        var plotValue: Double {
            NSDecimalNumber(decimal: value).doubleValue
        }
    }

    func unknownValue(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown()
    }

    func periodTitle(for period: SubtensorPricePeriod, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let title: String

        switch period {
        case .day:
            title = strings.commonPeriod1d()
        case .week:
            title = strings.commonPeriod7d()
        case .month:
            title = strings.commonPeriod1m()
        case .quarter:
            title = strings.commonPeriod3m()
        case .year:
            title = strings.commonPeriod1y()
        case .all:
            title = strings.commonPeriodAll()
        }

        return title.uppercased(with: locale)
    }

    func series(of history: SubtensorPriceHistory, isFiat: Bool) -> [SeriesPoint] {
        history.points
            .map { SeriesPoint(date: $0.date, value: isFiat ? $0.fiatPerAlpha : $0.taoPerAlpha) }
            .filter(\.plotValue.isFinite)
    }

    func periodChange(of history: SubtensorPriceHistory, isFiat: Bool) -> Decimal? {
        isFiat ? history.changeInFiat : history.changeInTao
    }

    func formatSpotPrice(for params: SubtensorPriceWidgetParams, locale: Locale) -> String {
        guard let spotPrice = params.spotPrice else {
            return unknownValue(for: locale)
        }

        guard params.isFiat else {
            return tokenFormatter.value(for: locale).stringFromDecimal(spotPrice) ?? unknownValue(for: locale)
        }

        return params.taoPrice.map { priceData in
            balanceViewModelFactory.priceFromAmount(spotPrice, priceData: priceData).value(for: locale)
        } ?? unknownValue(for: locale)
    }

    func formatPointPrice(_ value: Decimal, params: SubtensorPriceWidgetParams, locale: Locale) -> String {
        guard params.isFiat else {
            return tokenFormatter.value(for: locale).stringFromDecimal(value) ?? unknownValue(for: locale)
        }

        return balanceViewModelFactory.priceFromFiatAmount(value, currencyId: params.currencyId).value(for: locale)
    }

    func formatAxis(_ value: Double, params: SubtensorPriceWidgetParams, locale: Locale) -> String {
        let decimal = Decimal(value)

        guard params.isFiat else {
            return axisFormatter.value(for: locale).stringFromDecimal(decimal) ?? unknownValue(for: locale)
        }

        let fiatInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: params.currencyId)

        return formatterFactory.createAssetPriceFormatter(for: fiatInfo)
            .value(for: locale)
            .stringFromDecimal(decimal) ?? unknownValue(for: locale)
    }

    func formatPointDate(_ date: Date, locale: Locale) -> String {
        let formatter = date.sameYear(as: Date())
            ? DateFormatter.chartEntryDate
            : DateFormatter.chartEntryWithYear

        return formatter.value(for: locale).string(from: date)
    }

    func createChange(
        _ change: Decimal?,
        suffix: String,
        locale: Locale
    ) -> SubtensorSubnetPriceHeaderViewModel.Change {
        let formatter = NumberFormatter.signedPercentSingle
        formatter.locale = locale

        guard let change, let percent = formatter.stringFromDecimal(change) else {
            return .hidden
        }

        let text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiJoinDotFormat(
            percent,
            suffix
        )

        return .value(text: text, isRising: change >= 0)
    }

    func createSpotHeader(
        for params: SubtensorPriceWidgetParams,
        locale: Locale
    ) -> SubtensorSubnetPriceHeaderViewModel {
        let change: SubtensorSubnetPriceHeaderViewModel.Change

        switch params.history {
        case .loading:
            change = .loading
        case .notListed, .failed:
            change = .hidden
        case let .available(history):
            change = createChange(
                periodChange(of: history, isFiat: params.isFiat),
                suffix: periodTitle(for: params.period, locale: locale),
                locale: locale
            )
        }

        return SubtensorSubnetPriceHeaderViewModel(
            caption: params.caption,
            price: formatSpotPrice(for: params, locale: locale),
            change: change,
            currency: params.currency
        )
    }

    func createPointHeader(
        for params: SubtensorPriceWidgetParams,
        locale: Locale
    ) -> SubtensorSubnetPriceHeaderViewModel? {
        guard
            let index = params.selectedPoint,
            case let .available(history) = params.history else {
            return nil
        }

        let points = series(of: history, isFiat: params.isFiat)

        guard points.indices.contains(index), let first = points.first else {
            return nil
        }

        let point = points[index]
        let pointChange = first.value > 0 ? (point.value - first.value) / first.value : nil
        let wholePeriodChange = index == points.count - 1 ? periodChange(of: history, isFiat: params.isFiat) : nil

        let change = if let wholePeriodChange {
            createChange(wholePeriodChange, suffix: periodTitle(for: params.period, locale: locale), locale: locale)
        } else {
            createChange(pointChange, suffix: formatPointDate(point.date, locale: locale), locale: locale)
        }

        return SubtensorSubnetPriceHeaderViewModel(
            caption: params.caption,
            price: formatPointPrice(point.value, params: params, locale: locale),
            change: change,
            currency: params.currency
        )
    }

    func applyingSpotPrice(to params: SubtensorPriceWidgetParams) -> SubtensorPriceWidgetParams {
        guard
            case let .available(history) = params.history,
            let spotPrice = params.spotPrice,
            spotPrice > 0,
            let latest = history.points.last else {
            return params
        }

        let fiatRate = params.taoPrice?.decimalRate

        var updatedParams = params
        updatedParams.history = .available(
            history.replacingLatest(
                with: SubtensorPricePoint(
                    date: Date(),
                    taoPerAlpha: spotPrice,
                    fiatPerAlpha: fiatRate.map { spotPrice * $0 } ?? latest.fiatPerAlpha
                )
            )
        )

        return updatedParams
    }

    func createAnyHeader(
        for params: SubtensorPriceWidgetParams,
        locale: Locale
    ) -> SubtensorSubnetPriceHeaderViewModel {
        createPointHeader(for: params, locale: locale) ?? createSpotHeader(for: params, locale: locale)
    }

    func createUnavailableChart(locale: Locale) -> SubtensorSubnetChartViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return .unavailable(
            title: strings.stakingSubtensorUiDetailHistoryUnavailable(),
            details: strings.stakingSubtensorUiDetailHistorySource()
        )
    }

    func createChart(for params: SubtensorPriceWidgetParams, locale: Locale) -> SubtensorSubnetChartViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch params.history {
        case .loading:
            return .loading
        case .notListed:
            return createUnavailableChart(locale: locale)
        case .failed:
            return .failed(title: strings.stakingSubtensorUiDetailHistoryFailed(), action: strings.commonTryAgain())
        case let .available(history):
            let values = series(of: history, isFiat: params.isFiat).map(\.plotValue)

            guard
                values.count > 1,
                let first = values.first,
                let last = values.last,
                let minimum = values.min(),
                let maximum = values.max() else {
                return createUnavailableChart(locale: locale)
            }

            return .chart(
                SubtensorPriceChartViewModel(
                    values: values,
                    axisLabels: [
                        formatAxis(maximum, params: params, locale: locale),
                        formatAxis(minimum, params: params, locale: locale)
                    ],
                    isRising: periodChange(of: history, isFiat: params.isFiat).map { $0 >= 0 } ?? (last >= first)
                )
            )
        }
    }

    func createPeriods(
        for params: SubtensorPriceWidgetParams,
        locale: Locale
    ) -> SubtensorSubnetPeriodsViewModel {
        SubtensorSubnetPeriodsViewModel(
            titles: Self.periods.map { periodTitle(for: $0, locale: locale) },
            selectedIndex: Self.periods.firstIndex(of: params.period) ?? 0,
            isEnabled: params.history != .notListed
        )
    }
}

extension SubtensorPriceWidgetViewModelFactory: SubtensorPriceWidgetFactoryProtocol {
    func createCaption(
        subnetTitle: String,
        stamps: [SubtensorBackendStamp],
        now: Date,
        locale: Locale
    ) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let caption = strings.stakingSubtensorUiDetailPriceFormat(subnetTitle)

        let agedHint = SubtensorFreshnessFormatter.agedHint(
            for: SubtensorBackendStamp.aggregate(stamps),
            now: now,
            locale: locale
        )

        return agedHint.map { strings.stakingSubtensorUiJoinDotFormat(caption, $0) } ?? caption
    }

    func createWidget(
        for params: SubtensorPriceWidgetParams,
        locale: Locale
    ) -> SubtensorPriceWidgetViewModel {
        let params = applyingSpotPrice(to: params)

        return SubtensorPriceWidgetViewModel(
            header: createAnyHeader(for: params, locale: locale),
            chart: createChart(for: params, locale: locale),
            periods: createPeriods(for: params, locale: locale)
        )
    }

    func createHeader(
        for params: SubtensorPriceWidgetParams,
        locale: Locale
    ) -> SubtensorSubnetPriceHeaderViewModel {
        createAnyHeader(for: applyingSpotPrice(to: params), locale: locale)
    }
}
