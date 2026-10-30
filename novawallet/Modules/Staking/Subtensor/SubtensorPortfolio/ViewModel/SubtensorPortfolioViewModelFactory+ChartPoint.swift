import Foundation
import Foundation_iOS

struct SubtensorPortfolioChartSelection {
    let header: SubtensorPortfolioHeaderViewModel
    let points: [SubtensorPortfolioValuePoint]
}

protocol SubtensorPortfolioChartFactoryProtocol {
    func createChartSelection(for state: SubtensorPortfolioState, locale: Locale) -> SubtensorPortfolioChartSelection?

    func createHeader(
        for selection: SubtensorPortfolioChartSelection,
        state: SubtensorPortfolioState,
        locale: Locale
    ) -> SubtensorPortfolioHeaderViewModel
}

extension SubtensorPortfolioViewModelFactory: SubtensorPortfolioChartFactoryProtocol {
    func createChartSelection(for state: SubtensorPortfolioState, locale: Locale) -> SubtensorPortfolioChartSelection? {
        guard let portfolio = state.portfolio, !state.isValuationPending, !state.groups.isEmpty else {
            return nil
        }

        return createSelection(for: portfolio, state: state, locale: locale)
    }

    func createHeader(
        for selection: SubtensorPortfolioChartSelection,
        state: SubtensorPortfolioState,
        locale: Locale
    ) -> SubtensorPortfolioHeaderViewModel {
        let header = selection.header
        let points = selection.points

        guard
            let index = state.chartPoint,
            let price = state.price.value,
            points.indices.contains(index) else {
            return header
        }

        let point = points[index]

        let fiat = balanceViewModelFactory.priceFromFiatAmount(point.fiatValue, currencyId: price.currencyId)

        return SubtensorPortfolioHeaderViewModel(
            total: balanceViewModelFactory.amountFromValue(point.taoValue, roundingMode: .down).value(for: locale),
            fiat: .value(fiat.value(for: locale)),
            date: formatPointDate(point.date, locale: locale),
            chart: header.chart,
            periods: header.periods
        )
    }
}

private extension SubtensorPortfolioViewModelFactory {
    func formatPointDate(_ date: Date, locale: Locale) -> String {
        let formatter = date.sameYear(as: Date())
            ? DateFormatter.chartEntryDate
            : DateFormatter.chartEntryWithYear

        return formatter.value(for: locale).string(from: date)
    }
}
