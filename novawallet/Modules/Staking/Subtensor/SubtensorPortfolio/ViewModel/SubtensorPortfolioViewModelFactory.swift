import Foundation
import Foundation_iOS

protocol SubtensorPortfolioViewModelFactoryProtocol: SubtensorPortfolioChartFactoryProtocol {
    func createViewModel(for state: SubtensorPortfolioState, locale: Locale) -> SubtensorPortfolioViewModel
}

final class SubtensorPortfolioViewModelFactory {
    static let defaultPeriod = SubtensorPricePeriod.month
    private static let placeholderRows = 2

    let chainAsset: ChainAsset
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let iconFactory: SubtensorSubnetIconFactoryProtocol = SubtensorSubnetIconViewModelFactory()
    let assetIconFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory()
    let formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    let balanceViewModelFactory: PrimitiveBalanceViewModelFactoryProtocol

    init(
        chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.priceAssetInfoFactory = priceAssetInfoFactory

        balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
    }
}

private extension SubtensorPortfolioViewModelFactory {
    struct ChartContent {
        let chart: SubtensorPortfolioChartViewModel
        let change: SubtensorRowState<SubtensorPortfolioChangeViewModel>
        var points: [SubtensorPortfolioValuePoint] = []
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

    func formatSignedPercent(_ value: Decimal, locale: Locale) -> String? {
        let formatter = NumberFormatter.subtensorSignedPercentSingle.value(for: locale)

        return formatter.stringFromDecimal(value)
    }

    func createPeriods(for state: SubtensorPortfolioState, locale: Locale) -> SubtensorPortfolioPeriodsViewModel {
        SubtensorPortfolioPeriodsViewModel(
            titles: SubtensorPricePeriod.selectable.map { $0.title(for: locale) },
            selectedIndex: SubtensorPricePeriod.selectable.firstIndex(of: state.period) ?? 0
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

        guard portfolio.isFullyPriced else {
            return unavailable
        }

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

            let points = series.points.filter { NSDecimalNumber(decimal: $0.fiatValue).doubleValue.isFinite }

            guard let chart = createChartViewModel(for: points, series: series, price: price, locale: locale) else {
                return unavailable
            }

            let change = series.changeInFiat.flatMap { changeInFiat in
                createChange(changeInFiat, period: histories.period, locale: locale)
            }

            return ChartContent(
                chart: .chart(chart),
                change: change.map { .value($0) } ?? .hidden,
                points: points
            )
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
            period.title(for: locale)
        )

        return SubtensorPortfolioChangeViewModel(text: text, isRising: change >= 0)
    }

    func createChartViewModel(
        for points: [SubtensorPortfolioValuePoint],
        series: SubtensorPortfolioValueSeries,
        price: PriceData,
        locale: Locale
    ) -> SubtensorPriceChartViewModel? {
        let values = points.map { NSDecimalNumber(decimal: $0.fiatValue).doubleValue }

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
            formatter.stringFromDecimal(Decimal(value)) ?? .subtensorUnknown(for: locale)
        }

        return SubtensorPriceChartViewModel(
            series: .indexed(values),
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

        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let rate = SubtensorStakeRateCalculator.rootRate(of: group.positions, in: state.rootYields)
        let subtitle = state.rootYields != nil
            ? strings.stakingSubtensorUiPortfolioRootApyFormat(
                SubtensorApyFormatter.text(for: rate, style: .bare, locale: locale)
            )
            : nil

        return SubtensorPortfolioRowViewModel(
            icon: assetIconFactory.createAssetIconViewModel(from: chainAsset.assetDisplayInfo),
            title: strings.stakingSubtensorUiRootStaking(),
            subtitle: subtitle,
            value: formatTao(amount, locale: locale),
            symbol: chainAsset.assetDisplayInfo.symbol,
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
            ? chainAsset.assetDisplayInfo.subtensorAlphaAmount(
                group.totalAlpha,
                netuid: group.netuid,
                catalogue: state.catalogue,
                locale: locale
            )
            : nil

        let detail = state.isCatalogueUnavailable
            ? nil
            : subnet.flatMap { createWeeklyChange(for: $0.ref, state: state, locale: locale) }

        return SubtensorPortfolioRowViewModel(
            icon: iconFactory.icon(for: subnet, logos: state.subnetLogos),
            title: SubtensorSubnetNaming.titleWithSymbol(for: group.netuid, in: state.catalogue, locale: locale),
            subtitle: subtitle,
            value: value,
            symbol: chainAsset.assetDisplayInfo.symbol,
            detail: detail
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
            SubtensorPricePeriod.week.title(for: locale)
        )

        return .change(SubtensorPortfolioChangeViewModel(text: text, isRising: change >= 0))
    }

    func createEmpty(for state: SubtensorPortfolioState, locale: Locale) -> SubtensorPortfolioEmptyViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let fiat = state.price.value.map { price in
            formatFiat(0, price: price, locale: locale)
        }

        return SubtensorPortfolioEmptyViewModel(
            total: formatTao(0, locale: locale),
            fiat: fiat,
            rootSubtitle: state.networkRootRate.map {
                strings.stakingSubtensorUiPortfolioEmptyRootSubtitleFormat(
                    SubtensorApyFormatter.text(for: $0, style: .bare, locale: locale)
                )
            } ?? strings.stakingSubtensorUiPickerRootSubtitle()
        )
    }
}

extension SubtensorPortfolioViewModelFactory: SubtensorPortfolioViewModelFactoryProtocol {
    func createViewModel(for state: SubtensorPortfolioState, locale: Locale) -> SubtensorPortfolioViewModel {
        let groups = state.groups

        guard let portfolio = state.portfolio, !state.isValuationPending else {
            let rootRows = groups
                .filter { $0.netuid == SubtensorStakingPallet.rootNetuid }
                .map { createRootRow(for: $0, state: state, locale: locale) }
            let loadingRows = state.portfolio == nil ? Self.placeholderRows : groups.count - rootRows.count
            let header = createLoadingHeader(for: state, locale: locale)

            return SubtensorPortfolioViewModel(
                content: .positions(header: header, rows: rootRows, loadingRows: loadingRows),
                isSyncFailed: state.isSyncFailed,
                isRatesUnavailable: false
            )
        }

        guard !groups.isEmpty else {
            return SubtensorPortfolioViewModel(
                content: .empty(createEmpty(for: state, locale: locale)),
                isSyncFailed: state.isSyncFailed,
                isRatesUnavailable: false
            )
        }

        let rows = groups.map { group in
            group.netuid == SubtensorStakingPallet.rootNetuid
                ? createRootRow(for: group, state: state, locale: locale)
                : createSubnetRow(for: group, state: state, locale: locale)
        }

        let selection = createSelection(for: portfolio, state: state, locale: locale)

        return SubtensorPortfolioViewModel(
            content: .positions(header: createHeader(for: selection, state: state, locale: locale), rows: rows),
            isSyncFailed: state.isSyncFailed,
            isRatesUnavailable: state.isCatalogueUnavailable || state.isRootRateUnavailable
        )
    }

    func createSelection(
        for portfolio: SubtensorPortfolio,
        state: SubtensorPortfolioState,
        locale: Locale
    ) -> SubtensorPortfolioChartSelection {
        let chart = state.isCatalogueUnavailable
            ? ChartContent(chart: .hidden, change: .hidden)
            : createChart(for: portfolio, state: state, locale: locale)

        let total = decimal(portfolio.pricedTaoValue)

        let fiat: SubtensorRowState<String>

        switch state.price {
        case .loading:
            fiat = .loading
        case .loaded(.none):
            fiat = .hidden
        case let .loaded(.some(price)):
            fiat = .value(formatFiat(total, price: price, locale: locale))
        }

        let header = SubtensorPortfolioHeaderViewModel(
            total: portfolio.isFullyPriced ? formatTao(total, locale: locale) : .subtensorUnknown(for: locale),
            fiat: portfolio.isFullyPriced ? fiat : .hidden,
            change: chart.change,
            chart: chart.chart,
            periods: createPeriods(for: state, locale: locale)
        )

        return SubtensorPortfolioChartSelection(header: header, points: chart.points)
    }
}
