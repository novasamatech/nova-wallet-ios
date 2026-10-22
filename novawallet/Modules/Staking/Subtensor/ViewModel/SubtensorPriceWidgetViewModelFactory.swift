import Foundation
import Foundation_iOS

struct SubtensorPriceWidgetParams {
    let history: SubtensorSubnetHistoryState
    let period: SubtensorPricePeriod
    let isFiat: Bool
    let taoPrice: PriceData?
    let currencyId: Int?
    let chartEndDate: Date
    let avgBuyPrice: Decimal?
}

struct SubtensorPriceHeaderParams {
    let caption: String
    let spotPrice: Decimal?
    let currency: SubtensorSubnetCurrencyViewModel?
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
        header: SubtensorPriceHeaderParams,
        locale: Locale
    ) -> SubtensorPriceWidgetViewModel

    func createHeader(
        _ header: SubtensorPriceHeaderParams,
        for params: SubtensorPriceWidgetParams,
        locale: Locale
    ) -> SubtensorSubnetPriceHeaderViewModel
}

final class SubtensorPriceWidgetViewModelFactory {
    static let defaultPeriod = SubtensorPricePeriod.week

    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    let tokenFormatter: LocalizableResource<TokenFormatter>
    let balanceViewModelFactory: PrimitiveBalanceViewModelFactoryProtocol

    init(
        chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) {
        self.priceAssetInfoFactory = priceAssetInfoFactory

        let taoInfo = chainAsset.assetDisplayInfo

        tokenFormatter = formatterFactory.createTokenFormatter(for: taoInfo)
        balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: taoInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
    }
}

private extension SubtensorPriceWidgetViewModelFactory {
    func formatSpotPrice(
        for header: SubtensorPriceHeaderParams,
        params: SubtensorPriceWidgetParams,
        locale: Locale
    ) -> String {
        guard let spotPrice = header.spotPrice else {
            return .subtensorUnknown(for: locale)
        }

        guard params.isFiat else {
            return tokenFormatter.value(for: locale).stringFromDecimal(spotPrice) ?? .subtensorUnknown(for: locale)
        }

        return params.taoPrice.map { priceData in
            balanceViewModelFactory.priceFromAmount(spotPrice, priceData: priceData).value(for: locale)
        } ?? .subtensorUnknown(for: locale)
    }

    func formatPointPrice(_ value: Decimal, params: SubtensorPriceWidgetParams, locale: Locale) -> String {
        guard params.isFiat else {
            return tokenFormatter.value(for: locale).stringFromDecimal(value) ?? .subtensorUnknown(for: locale)
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
        let formatter = NumberFormatter.subtensorSignedPercentSingle.value(for: locale)

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
                suffix: params.period.title(for: locale),
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

    func createPeriods(
        for params: SubtensorPriceWidgetParams,
        locale: Locale
    ) -> SubtensorSubnetPeriodsViewModel {
        SubtensorSubnetPeriodsViewModel(
            titles: SubtensorPricePeriod.subnetSelectable.map { $0.title(for: locale) },
            selectedIndex: SubtensorPricePeriod.subnetSelectable.firstIndex(of: params.period) ?? 0,
            isEnabled: params.history != .notListed && params.history != .loading
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
        header: SubtensorPriceHeaderParams,
        locale: Locale
    ) -> SubtensorPriceWidgetViewModel {
        SubtensorPriceWidgetViewModel(
            header: createHeader(header, for: params, locale: locale),
            chart: createChart(for: params, locale: locale),
            periods: createPeriods(for: params, locale: locale)
        )
    }

    func createHeader(
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
            price = .subtensorUnknown(for: locale)
        case let .point(sourceIndex):
            guard case let .available(history) = params.history,
                  let series = datedSeries(history: history, params: params),
                  let point = series.points.first(where: { $0.sourceIndex == sourceIndex }) else {
                return SubtensorSubnetPriceHeaderViewModel(
                    caption: header.caption,
                    price: .subtensorUnknown(for: locale),
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
}

extension SubtensorPriceWidgetViewModelFactory {
    func formatAxis(_ value: Double, params: SubtensorPriceWidgetParams, locale: Locale) -> String {
        guard params.isFiat else {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .decimal
            formatter.usesSignificantDigits = true
            formatter.minimumSignificantDigits = Constants.axisSignificantDigits
            formatter.maximumSignificantDigits = max(
                Constants.axisSignificantDigits,
                abs(value) >= 1 ? Int(log10(abs(value))) + 1 : 0
            )

            return formatter.string(from: NSNumber(value: value)) ?? .subtensorUnknown(for: locale)
        }

        let fiatInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: params.currencyId)

        return formatterFactory.createAssetPriceFormatter(for: fiatInfo)
            .value(for: locale)
            .stringFromDecimal(Decimal(value)) ?? .subtensorUnknown(for: locale)
    }
}

private extension SubtensorPriceWidgetViewModelFactory {
    enum Constants {
        static let axisSignificantDigits = 3
    }
}

extension SubtensorPricePeriod {
    func title(for locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch self {
        case .day:
            return strings.commonPeriod1d().uppercased(with: locale)
        case .week:
            return strings.commonPeriod7d().uppercased(with: locale)
        case .month:
            return strings.commonPeriod30d().uppercased(with: locale)
        case .quarter:
            return strings.commonPeriod90d().uppercased(with: locale)
        case .year:
            return strings.commonPeriod1y().uppercased(with: locale)
        case .all:
            return strings.commonPeriodAll().capitalized(with: locale)
        }
    }
}
