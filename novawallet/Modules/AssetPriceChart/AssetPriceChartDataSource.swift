import Foundation
import DGCharts

protocol AssetPriceChartViewDataSourceProtocol {
    func createChartData(
        using entries: [ChartDataEntry],
        lineColor: UIColor,
        showHighlighter: Bool
    ) -> LineChartData

    func createDataSets(for selectedEntry: ChartDataEntry?) -> [LineChartDataSetProtocol]?

    func createEmptyChartData() -> LineChartData

    func createColors() -> AssetPriceChart.Colors?

    func set(widgetViewModel: AssetPriceChartWidgetViewModel)

    func set(priceUpdateViewModel: AssetPriceChartPriceUpdateViewModel)

    func getTitle() -> String?

    func getCurrentPrice() -> LoadableViewModelState<String?>?

    func getPeriodChange() -> LoadableViewModelState<PricePeriodChangeViewModel>?

    func getChartModel() -> LoadableViewModelState<PriceChartViewModel>?

    func getPeriodControlModel() -> PriceChartPeriodControlViewModel?
}

final class AssetPriceChartViewDataSource {
    private var widgetViewModel: AssetPriceChartWidgetViewModel?
    private var entryIndexesByX: [Double: Int]?
}

// MARK: Private

private extension AssetPriceChartViewDataSource {
    func createChartDataSet(
        using entries: [ChartDataEntry],
        lineColor: UIColor,
        showHighlighter: Bool
    ) -> LineChartDataSetProtocol {
        let lineDataSet = LineChartDataSet(entries: entries)
        lineDataSet.mode = .cubicBezier
        lineDataSet.drawCirclesEnabled = false
        lineDataSet.lineWidth = 1.5
        lineDataSet.drawValuesEnabled = false
        lineDataSet.setColor(lineColor)
        lineDataSet.drawHorizontalHighlightIndicatorEnabled = false
        lineDataSet.drawVerticalHighlightIndicatorEnabled = showHighlighter
        lineDataSet.highlightEnabled = true
        lineDataSet.highlightColor = R.color.colorNeutralPriceChartLine()!

        return lineDataSet
    }
}

// MARK: AssetPriceChartDataSourceProtocol

extension AssetPriceChartViewDataSource: AssetPriceChartViewDataSourceProtocol {
    func createChartData(
        using entries: [ChartDataEntry],
        lineColor: UIColor,
        showHighlighter: Bool
    ) -> LineChartData {
        let dataSet = createChartDataSet(
            using: entries,
            lineColor: lineColor,
            showHighlighter: showHighlighter
        )

        let lineData = LineChartData(dataSets: [dataSet])

        return lineData
    }

    func createDataSets(for selectedEntry: ChartDataEntry?) -> [LineChartDataSetProtocol]? {
        guard
            let chartModel = widgetViewModel?.chartModel.value,
            let colors = createColors()
        else {
            return nil
        }

        guard
            let selectedEntry,
            let selectedIndex = entryIndexesByX?[selectedEntry.x]
        else {
            let dataSet = createChartDataSet(
                using: chartModel.dataSet,
                lineColor: colors.chartHighlightedLineColor,
                showHighlighter: true
            )

            return [dataSet]
        }

        let currentEntries = chartModel.dataSet

        let entriesBefore = Array(currentEntries[0 ..< selectedIndex + 1])
        let entriesAfter = Array(currentEntries[entriesBefore.count - 1 ..< currentEntries.count])

        let dataSetBefore = createChartDataSet(
            using: entriesBefore,
            lineColor: colors.chartHighlightedLineColor,
            showHighlighter: true
        )
        let dataSetAfter = createChartDataSet(
            using: entriesAfter,
            lineColor: R.color.colorNeutralPriceChartLine()!,
            showHighlighter: true
        )

        return [dataSetBefore, dataSetAfter]
    }

    func createEmptyChartData() -> LineChartData {
        let entriesCount = 100

        let entries = (0 ..< entriesCount).map {
            let xPoint = Double($0)
            let yPoint = sin(2.0 * Double.pi * Double($0) / Double(entriesCount) * 2) + 1

            return ChartDataEntry(x: xPoint, y: yPoint)
        }

        let dataSet = LineChartDataSet(entries: entries)
        dataSet.mode = .cubicBezier
        dataSet.drawCirclesEnabled = false
        dataSet.lineWidth = 1.5
        dataSet.drawValuesEnabled = false
        dataSet.setColor(R.color.colorNeutralPriceChartLine()!)
        dataSet.drawHorizontalHighlightIndicatorEnabled = false
        dataSet.drawVerticalHighlightIndicatorEnabled = false
        dataSet.highlightEnabled = false

        let lineData = LineChartData(dataSet: dataSet)

        return lineData
    }

    func createColors() -> AssetPriceChart.Colors? {
        guard let widgetViewModel else { return nil }

        let changeTextColor: UIColor = if let model = widgetViewModel.periodChange.value {
            switch model.changeType {
            case .increase:
                R.color.colorTextPositive()!
            case .decrease:
                R.color.colorTextNegative()!
            }
        } else {
            R.color.colorTextSecondary()!
        }

        let colors = if let chartModel = widgetViewModel.chartModel.value {
            switch chartModel.changeType {
            case .increase:
                AssetPriceChart.Colors(
                    chartHighlightedLineColor: R.color.colorPositivePriceChartLine()!,
                    entryDotShadowColor: R.color.colorPriceChartPositiveShadow()!,
                    changeTextColor: changeTextColor
                )
            case .decrease:
                AssetPriceChart.Colors(
                    chartHighlightedLineColor: R.color.colorNegativePriceChartLine()!,
                    entryDotShadowColor: R.color.colorPriceChartNegativeShadow()!,
                    changeTextColor: changeTextColor
                )
            }
        } else {
            AssetPriceChart.Colors(
                chartHighlightedLineColor: R.color.colorNeutralPriceChartLine()!,
                entryDotShadowColor: .clear,
                changeTextColor: changeTextColor
            )
        }

        return colors
    }

    func set(widgetViewModel: AssetPriceChartWidgetViewModel) {
        self.widgetViewModel = widgetViewModel

        guard let chartModel = widgetViewModel.chartModel.value else {
            entryIndexesByX = nil
            return
        }

        entryIndexesByX = chartModel.dataSet
            .enumerated()
            .reduce(into: [:]) { $0[$1.element.x] = $1.offset }
    }

    func set(priceUpdateViewModel: AssetPriceChartPriceUpdateViewModel) {
        widgetViewModel = widgetViewModel?.byUpdating(with: priceUpdateViewModel)
    }

    func getTitle() -> String? {
        widgetViewModel?.title
    }

    func getCurrentPrice() -> LoadableViewModelState<String?>? {
        widgetViewModel?.currentPrice
    }

    func getPeriodChange() -> LoadableViewModelState<PricePeriodChangeViewModel>? {
        widgetViewModel?.periodChange
    }

    func getChartModel() -> LoadableViewModelState<PriceChartViewModel>? {
        widgetViewModel?.chartModel
    }

    func getPeriodControlModel() -> PriceChartPeriodControlViewModel? {
        widgetViewModel?.periodControlModel
    }
}
