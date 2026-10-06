import Foundation
import Foundation_iOS

protocol SubnetPortfolioViewModelFactoryProtocol {
    func createViewModel(for state: SubtensorPortfolioState, locale: Locale) -> SubtensorPortfolioViewModel
}

final class SubtensorPortfolioViewModelFactory {
    static let periods: [SubtensorPricePeriod] = [.day, .week, .month, .year, .all]
    static let defaultPeriod = SubtensorPricePeriod.month

    let chainAsset: ChainAsset
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let iconFactory: SubtensorSubnetIconFactoryProtocol
    let assetIconFactory: AssetIconViewModelFactoryProtocol
    let formatterFactory: AssetBalanceFormatterFactoryProtocol
    let balanceViewModelFactory: PrimitiveBalanceViewModelFactoryProtocol

    init(
        chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        iconFactory: SubtensorSubnetIconFactoryProtocol = SubtensorSubnetIconViewModelFactory(),
        assetIconFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory(),
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) {
        self.chainAsset = chainAsset
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.iconFactory = iconFactory
        self.assetIconFactory = assetIconFactory
        self.formatterFactory = formatterFactory

        balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
    }
}

private extension SubtensorPortfolioViewModelFactory {
    struct ChartContent {
        let chart: SubtensorPortfolioChartViewModel
        let change: SubtensorPortfolioLoadable<SubtensorPortfolioChangeViewModel>
    }

    var precision: Int16 {
        chainAsset.asset.decimalPrecision
    }

    func decimal(_ amount: Balance) -> Decimal {
        Decimal.fromSubstrateAmount(amount, precision: precision) ?? 0
    }

    func formatTao(_ amount: Decimal, locale: Locale) -> String {
        balanceViewModelFactory.amountFromValue(amount, roundingMode: .down).value(for: locale)
    }

    func formatFiat(_ amount: Decimal, price: PriceData, locale: Locale) -> String {
        balanceViewModelFactory.priceFromAmount(amount, priceData: price).value(for: locale)
    }

    func formatAlpha(
        _ amount: Balance,
        netuid: UInt16,
        catalogue: SubtensorSubnetCatalogue?,
        locale: Locale
    ) -> String {
        let taoInfo = chainAsset.assetDisplayInfo

        let alphaInfo = AssetBalanceDisplayInfo(
            displayPrecision: taoInfo.displayPrecision,
            assetPrecision: taoInfo.assetPrecision,
            symbol: SubtensorSubnetNaming.symbol(for: netuid, in: catalogue),
            symbolValueSeparator: taoInfo.symbolValueSeparator,
            symbolPosition: taoInfo.symbolPosition,
            icon: nil
        )

        let text = formatterFactory.createTokenFormatter(for: alphaInfo)
            .value(for: locale)
            .stringFromDecimal(decimal(amount)) ?? unknownValue(for: locale)

        return "\u{2066}\(text)\u{2069}"
    }

    func formatSignedPercent(_ value: Decimal, locale: Locale) -> String? {
        let formatter = NumberFormatter.signedPercentSingle
        formatter.locale = locale

        return formatter.stringFromDecimal(value)
    }

    func unknownValue(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown()
    }

    func periodTitle(for period: SubtensorPricePeriod, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch period {
        case .day:
            return strings.commonPeriod1d().uppercased(with: locale)
        case .week:
            return strings.commonPeriod7d().uppercased(with: locale)
        case .month:
            return strings.commonPeriod30d().uppercased(with: locale)
        case .quarter:
            return strings.commonPeriod3m().uppercased(with: locale)
        case .year:
            return strings.commonPeriod1y().uppercased(with: locale)
        case .all:
            return strings.commonPeriodAll().capitalized(with: locale)
        }
    }

    func createPeriods(for state: SubtensorPortfolioState, locale: Locale) -> SubtensorPortfolioPeriodsViewModel {
        SubtensorPortfolioPeriodsViewModel(
            titles: Self.periods.map { periodTitle(for: $0, locale: locale) },
            selectedIndex: Self.periods.firstIndex(of: state.period) ?? 0
        )
    }

    func createLoadingHeader(for state: SubtensorPortfolioState, locale: Locale) -> SubtensorPortfolioHeaderViewModel {
        SubtensorPortfolioHeaderViewModel(
            total: nil,
            fiat: .loading,
            change: .loading,
            chart: .loading,
            periods: createPeriods(for: state, locale: locale)
        )
    }

    func createHeader(
        for portfolio: SubtensorPortfolio,
        state: SubtensorPortfolioState,
        locale: Locale
    ) -> SubtensorPortfolioHeaderViewModel {
        let total = decimal(portfolio.pricedTaoValue)

        let fiat: SubtensorPortfolioLoadable<String>

        switch state.price {
        case .loading:
            fiat = .loading
        case .loaded(.none):
            fiat = .hidden
        case let .loaded(.some(price)):
            fiat = .loaded(formatFiat(total, price: price, locale: locale))
        }

        let chart = createChart(for: portfolio, state: state, locale: locale)

        return SubtensorPortfolioHeaderViewModel(
            total: formatTao(total, locale: locale),
            fiat: fiat,
            change: chart.change,
            chart: chart.chart,
            periods: createPeriods(for: state, locale: locale)
        )
    }

    func createChart(
        for portfolio: SubtensorPortfolio,
        state: SubtensorPortfolioState,
        locale: Locale
    ) -> ChartContent {
        let unavailable = ChartContent(
            chart: .unavailable(
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiChartUnavailable()
            ),
            change: .hidden
        )

        switch (state.price, state.histories) {
        case (.loaded(.none), _), (_, .failed):
            return unavailable
        case (.loading, _), (_, .loading):
            return ChartContent(chart: .loading, change: .loading)
        case let (.loaded(.some(price)), .loaded(histories)):
            guard let taoPrice = price.decimalRate else {
                return unavailable
            }

            let series = SubtensorPortfolioValueSeriesCalculator.calculate(
                portfolio: portfolio,
                histories: histories,
                currentTaoPrice: taoPrice,
                precision: precision
            )

            guard let chart = createChartViewModel(for: series, price: price, locale: locale) else {
                return unavailable
            }

            let change = series.changeInFiat.flatMap { changeInFiat in
                createChange(changeInFiat, period: histories.period, locale: locale)
            }

            return ChartContent(chart: .chart(chart), change: change.map { .loaded($0) } ?? .hidden)
        }
    }

    func createChange(
        _ change: Decimal,
        period: SubtensorPricePeriod,
        locale: Locale
    ) -> SubtensorPortfolioChangeViewModel? {
        guard let percent = formatSignedPercent(change, locale: locale) else {
            return nil
        }

        let text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiJoinDotFormat(
            percent,
            periodTitle(for: period, locale: locale)
        )

        return SubtensorPortfolioChangeViewModel(text: text, isRising: change >= 0)
    }

    func createChartViewModel(
        for series: SubtensorPortfolioValueSeries,
        price: PriceData,
        locale: Locale
    ) -> SubtensorPriceChartViewModel? {
        let values = series.points
            .map { NSDecimalNumber(decimal: $0.fiatValue).doubleValue }
            .filter(\.isFinite)

        guard
            values.count > 1,
            let first = values.first,
            let last = values.last,
            let minimum = values.min(),
            let maximum = values.max() else {
            return nil
        }

        let formatter = formatterFactory.createCompactTokenFormatter(
            for: priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: price.currencyId)
        ).value(for: locale)

        let axisLabels = [maximum, (maximum + minimum) / 2, minimum].map { value in
            formatter.stringFromDecimal(Decimal(value)) ?? unknownValue(for: locale)
        }

        return SubtensorPriceChartViewModel(
            values: values,
            axisLabels: axisLabels,
            isRising: series.changeInFiat.map { $0 >= 0 } ?? (last >= first)
        )
    }

    func createRootRow(
        for group: SubtensorPortfolioGroup,
        state: SubtensorPortfolioState,
        locale: Locale
    ) -> SubtensorPortfolioRowViewModel {
        let amount = decimal(group.taoValue ?? group.totalAlpha)

        let detail = state.price.value.map { price in
            SubtensorPortfolioRowViewModel.Detail.fiat(formatFiat(amount, price: price, locale: locale))
        }

        return SubtensorPortfolioRowViewModel(
            icon: assetIconFactory.createAssetIconViewModel(from: chainAsset.assetDisplayInfo),
            title: R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiRootStaking(),
            subtitle: state.rootRate.map { SubtensorApyFormatter.text(for: $0, style: .leading, locale: locale) },
            value: formatTao(amount, locale: locale),
            detail: detail
        )
    }

    func createSubnetRow(
        for group: SubtensorPortfolioGroup,
        state: SubtensorPortfolioState,
        locale: Locale
    ) -> SubtensorPortfolioRowViewModel {
        let subnet = state.catalogue?.subnet(for: group.netuid)

        let value = group.taoValue.map { formatTao(decimal($0), locale: locale).approximatelyEqual() } ??
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiPriceUnavailable()

        let subtitle = state.isCatalogueResolved
            ? formatAlpha(group.totalAlpha, netuid: group.netuid, catalogue: state.catalogue, locale: locale)
            : nil

        return SubtensorPortfolioRowViewModel(
            icon: iconFactory.icon(for: subnet, logos: state.subnetLogos),
            title: SubtensorSubnetNaming.titleWithSymbol(for: group.netuid, in: state.catalogue, locale: locale),
            subtitle: subtitle,
            value: value,
            detail: subnet.flatMap { createWeeklyChange(for: $0.ref, state: state, locale: locale) }
        )
    }

    func createWeeklyChange(
        for subnet: SubtensorSubnetRef,
        state: SubtensorPortfolioState,
        locale: Locale
    ) -> SubtensorPortfolioRowViewModel.Detail? {
        guard
            let change = state.weeklyChanges[subnet]?.availableValue?.change,
            let percent = formatSignedPercent(change, locale: locale) else {
            return nil
        }

        let text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiJoinSpaceFormat(
            percent,
            periodTitle(for: .week, locale: locale)
        )

        return .change(SubtensorPortfolioChangeViewModel(text: text, isRising: change >= 0))
    }

    func createEmpty(for state: SubtensorPortfolioState, locale: Locale) -> SubtensorPortfolioEmptyViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let fiat = state.price.value.map { price in
            formatFiat(0, price: price, locale: locale)
        }

        let rootSubtitle = state.rootRate.map { rate in
            strings.stakingSubtensorUiPortfolioEmptyRootSubtitleFormat(
                SubtensorApyFormatter.text(for: rate, style: .bare, locale: locale)
            )
        } ?? strings.stakingSubtensorUiPickerRootSubtitle()

        return SubtensorPortfolioEmptyViewModel(
            total: formatTao(0, locale: locale),
            fiat: fiat,
            rootSubtitle: rootSubtitle
        )
    }
}

extension SubtensorPortfolioViewModelFactory: SubnetPortfolioViewModelFactoryProtocol {
    func createViewModel(for state: SubtensorPortfolioState, locale: Locale) -> SubtensorPortfolioViewModel {
        guard let portfolio = state.portfolio, !state.isValuationPending else {
            return SubtensorPortfolioViewModel(
                content: .positions(header: createLoadingHeader(for: state, locale: locale), rows: nil),
                isSyncFailed: state.isSyncFailed
            )
        }

        let groups = state.groups

        guard !groups.isEmpty else {
            return SubtensorPortfolioViewModel(
                content: .empty(createEmpty(for: state, locale: locale)),
                isSyncFailed: state.isSyncFailed
            )
        }

        let rows = groups.map { group in
            group.netuid == SubtensorStakingPallet.rootNetuid
                ? createRootRow(for: group, state: state, locale: locale)
                : createSubnetRow(for: group, state: state, locale: locale)
        }

        return SubtensorPortfolioViewModel(
            content: .positions(header: createHeader(for: portfolio, state: state, locale: locale), rows: rows),
            isSyncFailed: state.isSyncFailed
        )
    }
}
