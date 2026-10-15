import Foundation

extension SubtensorPositionViewModelFactory {
    func createPriceWidget(for state: SubtensorPositionState, locale: Locale) -> SubtensorPriceWidgetViewModel? {
        guard !state.isRoot, state.hasResolvedHistory else {
            return nil
        }

        let params = SubtensorPriceWidgetParams(
            history: state.history,
            period: state.period,
            isFiat: false,
            taoPrice: nil,
            currencyId: nil,
            chartEndDate: state.chartEndDate
        )

        return priceWidgetFactory.createWidget(for: params, header: nil, locale: locale)
    }
}
