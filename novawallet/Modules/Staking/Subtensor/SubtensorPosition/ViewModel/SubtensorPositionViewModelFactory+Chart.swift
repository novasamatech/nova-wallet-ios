import Foundation
import Foundation_iOS

extension SubtensorPositionViewModelFactory {
    func createChart(for state: SubtensorPositionState, locale: Locale) -> SubtensorPositionChartViewModel? {
        guard !state.isRoot, state.hasResolvedHistory else {
            return nil
        }

        let periods = SubtensorSubnetPeriodsViewModel(
            titles: Self.periods.map { periodTitle(for: $0, locale: locale) },
            selectedIndex: Self.periods.firstIndex(of: state.period) ?? 0,
            isEnabled: state.history != .notListed
        )

        let chart = createChartContent(for: state.history, locale: locale)

        return SubtensorPositionChartViewModel(chart: chart, periods: periods)
    }
}

private extension SubtensorPositionViewModelFactory {
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

    func formatAxis(_ value: Double, locale: Locale) -> String {
        formatterFactory.createDisplayFormatter(for: chainAsset.assetDisplayInfo)
            .value(for: locale)
            .stringFromDecimal(Decimal(value)) ?? unknownValue(for: locale)
    }

    func createUnavailableChart(locale: Locale) -> SubtensorSubnetChartViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return .unavailable(
            title: strings.stakingSubtensorUiDetailHistoryUnavailable(),
            details: strings.stakingSubtensorUiDetailHistorySource()
        )
    }

    func createChartContent(for history: SubtensorSubnetHistoryState, locale: Locale) -> SubtensorSubnetChartViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch history {
        case .loading:
            return .loading
        case .notListed:
            return createUnavailableChart(locale: locale)
        case .failed:
            return .failed(title: strings.stakingSubtensorUiDetailHistoryFailed(), action: strings.commonTryAgain())
        case let .available(priceHistory):
            let values = priceHistory.points
                .map { NSDecimalNumber(decimal: $0.taoPerAlpha).doubleValue }
                .filter(\.isFinite)

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
                    axisLabels: [formatAxis(maximum, locale: locale), formatAxis(minimum, locale: locale)],
                    isRising: priceHistory.changeInTao.map { $0 >= 0 } ?? (last >= first)
                )
            )
        }
    }
}
