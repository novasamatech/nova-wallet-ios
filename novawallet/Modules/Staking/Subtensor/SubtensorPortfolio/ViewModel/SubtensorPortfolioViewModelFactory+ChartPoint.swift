import Foundation
import Foundation_iOS

struct SubtensorPortfolioChartSelection {
    let header: SubtensorPortfolioHeaderViewModel
    let points: [SubtensorPortfolioValuePoint]
}

protocol SubnetPortfolioChartFactoryProtocol {
    func createChartSelection(for state: SubtensorPortfolioState, locale: Locale) -> SubtensorPortfolioChartSelection?

    func createHeader(
        for selection: SubtensorPortfolioChartSelection,
        state: SubtensorPortfolioState,
        locale: Locale
    ) -> SubtensorPortfolioHeaderViewModel
}

extension SubtensorPortfolioViewModelFactory: SubnetPortfolioChartFactoryProtocol {
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
            points.indices.contains(index),
            let first = points.first else {
            return header
        }

        let point = points[index]

        let change: SubtensorPortfolioLoadable<SubtensorPortfolioChangeViewModel> = if index == points.count - 1 {
            header.change
        } else {
            createPointChange(from: first, to: point, locale: locale).map { .loaded($0) } ?? .hidden
        }

        let fiat = balanceViewModelFactory.priceFromFiatAmount(point.fiatValue, currencyId: price.currencyId)

        return SubtensorPortfolioHeaderViewModel(
            total: balanceViewModelFactory.amountFromValue(point.taoValue, roundingMode: .down).value(for: locale),
            fiat: .loaded(fiat.value(for: locale)),
            change: change,
            chart: header.chart,
            periods: header.periods
        )
    }
}

private extension SubtensorPortfolioViewModelFactory {
    func createPointChange(
        from first: SubtensorPortfolioValuePoint,
        to point: SubtensorPortfolioValuePoint,
        locale: Locale
    ) -> SubtensorPortfolioChangeViewModel? {
        guard first.fiatValue > 0 else {
            return nil
        }

        let change = (point.fiatValue - first.fiatValue) / first.fiatValue

        let formatter = NumberFormatter.signedPercentSingle
        formatter.locale = locale

        guard let percent = formatter.stringFromDecimal(change) else {
            return nil
        }

        let dateFormatter = point.date.sameYear(as: Date())
            ? DateFormatter.chartEntryDate
            : DateFormatter.chartEntryWithYear

        let text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiJoinDotFormat(
            percent,
            dateFormatter.value(for: locale).string(from: point.date)
        )

        return SubtensorPortfolioChangeViewModel(text: text, isRising: change >= 0)
    }
}
