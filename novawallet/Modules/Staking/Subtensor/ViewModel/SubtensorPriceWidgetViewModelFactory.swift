import Foundation
import Foundation_iOS

struct SubtensorPriceWidgetParams {
    let history: SubtensorSubnetHistoryState
    let period: SubtensorPricePeriod
    let taoPrice: PriceData?
    let chartEndDate: Date
    let avgBuyPrice: Decimal?
}

struct SubtensorPriceHeaderParams {
    let caption: String
    let spotPrice: Decimal?
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

    let formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    let tokenFormatter: LocalizableResource<TokenFormatter>
    let balanceViewModelFactory: PrimitiveBalanceViewModelFactoryProtocol

    init(
        chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) {
        let taoInfo = chainAsset.assetDisplayInfo

        tokenFormatter = formatterFactory.createTokenFormatter(for: taoInfo)
        balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: taoInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
    }
}

private extension SubtensorPriceWidgetViewModelFactory {
    func formatPrice(_ value: Decimal?, locale: Locale) -> String {
        value.flatMap { tokenFormatter.value(for: locale).stringFromDecimal($0) } ?? .subtensorUnknown(for: locale)
    }

    func formatFiat(_ value: Decimal?, params: SubtensorPriceWidgetParams, locale: Locale) -> String? {
        guard let value, let taoPrice = params.taoPrice else {
            return nil
        }

        return balanceViewModelFactory.priceFromAmount(value, priceData: taoPrice).value(for: locale)
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
            price: formatPrice(header.spotPrice, locale: locale),
            fiat: formatFiat(header.spotPrice, params: params, locale: locale),
            change: change,
            date: nil
        )
    }

    func createNoDataHeader(
        _ header: SubtensorPriceHeaderParams,
        date: Date,
        params: SubtensorPriceWidgetParams,
        locale: Locale
    ) -> SubtensorSubnetPriceHeaderViewModel {
        SubtensorSubnetPriceHeaderViewModel(
            caption: header.caption,
            price: .subtensorUnknown(for: locale),
            fiat: nil,
            change: .hidden,
            date: formatPointDate(date, endingAt: params.chartEndDate, locale: locale)
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
        switch header.selection {
        case .none:
            return createSpotHeader(header, for: params, locale: locale)
        case let .noData(date):
            return createNoDataHeader(header, date: date, params: params, locale: locale)
        case let .point(sourceIndex):
            guard case let .available(history) = params.history,
                  let series = datedSeries(history: history, params: params),
                  let point = series.points.first(where: { $0.sourceIndex == sourceIndex }) else {
                return createNoDataHeader(header, date: params.chartEndDate, params: params, locale: locale)
            }

            var change: Decimal?

            if displayChange(history: history, params: params) != nil, let first = series.points.first {
                change = (point.value - first.value) / first.value
            }

            return SubtensorSubnetPriceHeaderViewModel(
                caption: header.caption,
                price: formatPrice(point.value, locale: locale),
                fiat: formatFiat(point.value, params: params, locale: locale),
                change: createChange(change, suffix: params.period.title(for: locale), locale: locale),
                date: formatPointDate(point.date, endingAt: params.chartEndDate, locale: locale)
            )
        }
    }
}

extension SubtensorPriceWidgetViewModelFactory {
    func formatReferencePrice(_ value: Double, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesSignificantDigits = true
        formatter.minimumSignificantDigits = Constants.referenceSignificantDigits
        formatter.maximumSignificantDigits = max(
            Constants.referenceSignificantDigits,
            abs(value) >= 1 ? Int(log10(abs(value))) + 1 : 0
        )

        return formatter.string(from: NSNumber(value: value)) ?? .subtensorUnknown(for: locale)
    }
}

private extension SubtensorPriceWidgetViewModelFactory {
    enum Constants {
        static let referenceSignificantDigits = 3
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
            return strings.stakingRewardFiltersPeriodLastThreeMonthsShort().uppercased(with: locale)
        case .year:
            return strings.commonPeriod1y().uppercased(with: locale)
        case .all:
            return strings.commonPeriodAll().capitalized(with: locale)
        }
    }
}
