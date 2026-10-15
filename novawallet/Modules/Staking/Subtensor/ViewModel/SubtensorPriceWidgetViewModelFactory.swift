import Foundation
import Foundation_iOS

struct SubtensorPriceWidgetParams {
    let history: SubtensorSubnetHistoryState
    let period: SubtensorPricePeriod
    let isFiat: Bool
    let taoPrice: PriceData?
    let currencyId: Int?
    let chartEndDate: Date
}

struct SubtensorPriceHeaderParams {
    let caption: String
    let spotPrice: Decimal?
    let currency: SubtensorSubnetCurrencyViewModel
    let selection: SubtensorPriceChartSelection?
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
        header: SubtensorPriceHeaderParams?,
        locale: Locale
    ) -> SubtensorPriceWidgetViewModel

    func createHeader(
        _ header: SubtensorPriceHeaderParams,
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

    func formatSpotPrice(
        for header: SubtensorPriceHeaderParams,
        params: SubtensorPriceWidgetParams,
        locale: Locale
    ) -> String {
        guard let spotPrice = header.spotPrice else {
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

    func formatPointDate(_ date: Date, endingAt endDate: Date, locale: Locale) -> String {
        let formatter = date.sameYear(as: endDate)
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
        _ header: SubtensorPriceHeaderParams,
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
                displayChange(history: history, params: params),
                suffix: periodTitle(for: params.period, locale: locale),
                locale: locale
            )
        }

        return SubtensorSubnetPriceHeaderViewModel(
            caption: header.caption,
            price: formatSpotPrice(for: header, params: params, locale: locale),
            change: change,
            currency: header.currency
        )
    }

    func createAnyHeader(
        _ header: SubtensorPriceHeaderParams,
        for params: SubtensorPriceWidgetParams,
        locale: Locale
    ) -> SubtensorSubnetPriceHeaderViewModel {
        guard let selection = header.selection else {
            return createSpotHeader(header, for: params, locale: locale)
        }

        let date: Date
        let price: String
        var change: Decimal?

        switch selection {
        case let .noData(selectedDate):
            date = selectedDate
            price = unknownValue(for: locale)
        case let .point(sourceIndex):
            guard case let .available(history) = params.history,
                  let series = datedSeries(history: history, params: params),
                  let point = series.points.first(where: { $0.sourceIndex == sourceIndex }) else {
                return SubtensorSubnetPriceHeaderViewModel(
                    caption: header.caption,
                    price: unknownValue(for: locale),
                    change: .date(formatPointDate(params.chartEndDate, endingAt: params.chartEndDate, locale: locale)),
                    currency: header.currency
                )
            }

            date = point.date
            price = formatPointPrice(point.value, params: params, locale: locale)

            if displayChange(history: history, params: params) != nil, let first = series.points.first {
                change = (point.value - first.value) / first.value
            }
        }

        let dateText = formatPointDate(date, endingAt: params.chartEndDate, locale: locale)
        let detail = change.map { createChange($0, suffix: dateText, locale: locale) } ?? .date(dateText)

        return SubtensorSubnetPriceHeaderViewModel(
            caption: header.caption,
            price: price,
            change: detail,
            currency: header.currency
        )
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
        header: SubtensorPriceHeaderParams?,
        locale: Locale
    ) -> SubtensorPriceWidgetViewModel {
        SubtensorPriceWidgetViewModel(
            header: header.map { createAnyHeader($0, for: params, locale: locale) },
            chart: createChart(for: params, locale: locale),
            periods: createPeriods(for: params, locale: locale)
        )
    }

    func createHeader(
        _ header: SubtensorPriceHeaderParams,
        for params: SubtensorPriceWidgetParams,
        locale: Locale
    ) -> SubtensorSubnetPriceHeaderViewModel {
        createAnyHeader(header, for: params, locale: locale)
    }
}

extension SubtensorPriceWidgetViewModelFactory {
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
}
