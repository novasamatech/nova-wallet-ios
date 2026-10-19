import Foundation

extension SubtensorPriceWidgetViewModelFactory {
    func datedSeries(
        history: SubtensorPriceHistory,
        params: SubtensorPriceWidgetParams
    ) -> SubtensorPriceChartViewModel.DatedSeries? {
        let mapped: [SubtensorPriceChartViewModel.Point] = history.points.enumerated().map { index, point in
            SubtensorPriceChartViewModel.Point(
                sourceIndex: index,
                date: point.date,
                value: params.isFiat ? point.fiatPerAlpha : point.taoPerAlpha
            )
        }
        let valid = mapped.filter { $0.date.timeIntervalSince1970.isFinite && $0.plotValue.isFinite }
        let points = valid.sorted { first, second in
            first.date == second.date ? first.sourceIndex < second.sourceIndex : first.date < second.date
        }

        let end = params.chartEndDate

        guard end.timeIntervalSince1970.isFinite,
              let start = params.period.startDate(endingAt: end) ?? points.first?.date,
              start <= end else {
            return nil
        }

        let range = start ... end
        let visible = points.filter { range.contains($0.date) }

        guard visible.count > 1 else {
            return nil
        }

        return SubtensorPriceChartViewModel.DatedSeries(
            points: visible,
            range: range,
            predecessor: points.last { $0.date < start },
            coverageTolerance: params.period.coverageTolerance
        )
    }

    func displayChange(history: SubtensorPriceHistory, params: SubtensorPriceWidgetParams) -> Decimal? {
        guard let serviceChange = params.isFiat ? history.changeInFiat : history.changeInTao,
              NSDecimalNumber(decimal: serviceChange).doubleValue.isFinite,
              let series = datedSeries(history: history, params: params),
              let first = series.points.first,
              let last = series.points.last,
              first.value > 0,
              first.date.timeIntervalSince(series.range.lowerBound) <= params.period.coverageTolerance,
              series.range.upperBound.timeIntervalSince(last.date) <= params.period.coverageTolerance else {
            return nil
        }

        if first.sourceIndex == 0, last.sourceIndex == history.points.count - 1 {
            return serviceChange
        }

        return (last.value - first.value) / first.value
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
            let reference = params.avgBuyPrice.map { NSDecimalNumber(decimal: $0).doubleValue }

            guard let series = datedSeries(history: history, params: params),
                  let first = series.points.first,
                  let last = series.points.last,
                  let data = SubtensorPriceChartDataFactory.create(
                      series: .dated(series),
                      reference: reference,
                      availablePoints: 0
                  ) else {
                return createUnavailableChart(locale: locale)
            }

            let change = displayChange(history: history, params: params)

            return .chart(SubtensorPriceChartViewModel(
                series: .dated(series),
                axisLabels: [
                    formatAxis(data.yRange.upperBound, params: params, locale: locale),
                    formatAxis(data.yRange.lowerBound, params: params, locale: locale)
                ],
                isRising: change.map { $0 >= 0 } ?? (last.value >= first.value),
                reference: reference.map { value in
                    SubtensorPriceChartViewModel.Reference(
                        value: value,
                        label: strings.stakingSubtensorUiAvgBuyChartFormat(
                            formatAxis(value, params: params, locale: locale)
                        )
                    )
                }
            ))
        }
    }
}

private extension SubtensorPriceWidgetViewModelFactory {
    func createUnavailableChart(locale: Locale) -> SubtensorSubnetChartViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return .unavailable(
            title: strings.stakingSubtensorUiDetailHistoryUnavailable(),
            details: strings.stakingSubtensorUiDetailHistorySource()
        )
    }
}
