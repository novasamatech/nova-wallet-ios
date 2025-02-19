import UIKit
import DGCharts

final class AssetPriceChartViewController: UIViewController, ViewHolder {
    typealias RootViewType = AssetPriceChartViewLayout

    let presenter: AssetPriceChartPresenterProtocol

    var widgetViewModel: AssetPriceChartWidgetViewModel?

    init(presenter: AssetPriceChartPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AssetPriceChartViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
    }
}

// MARK: Private

private extension AssetPriceChartViewController {
    func updateView() {
        updateTexts()
        updateChart()
    }

    func updateTexts() {
        guard let colors = createColors() else {
            return
        }

        rootView.titleLabel.text = widgetViewModel?.title
        rootView.priceLabel.text = widgetViewModel?.currentPrice
        rootView.priceChangeLabel.text = widgetViewModel?.periodChange.value
        rootView.priceChangeLabel.textColor = colors.changeTextColor
    }

    func updateChart() {
        guard
            let widgetViewModel,
            let priceChartRenderer = rootView.chartView.renderer as? AssetPriceChartRenderer,
            let colors = createColors()
        else { return }

        priceChartRenderer.setSelectedEntry(nil)
        priceChartRenderer.setDotColor(
            nil,
            shadowColor: nil
        )

        let chartData = createChartData(
            using: widgetViewModel.chartModel.dataSet,
            lineColor: colors.chartHighlightedLineColor
        )
        rootView.chartView.data = chartData
    }

    func updateChart(with selectedEntry: ChartDataEntry) {
        guard
            let widgetViewModel,
            let priceChartRenderer = rootView.chartView.renderer as? AssetPriceChartRenderer,
            let colors = createColors()
        else { return }

        let currentEntries = widgetViewModel.chartModel.dataSet

        let entriesBefore = currentEntries.filter { $0.x <= selectedEntry.x }
        let entriesAfter = Array(currentEntries[entriesBefore.count - 1 ..< currentEntries.count])

        let dataBefore = createChartData(
            using: entriesBefore,
            lineColor: colors.chartHighlightedLineColor
        )
        let dataAfter = createChartData(
            using: entriesAfter,
            lineColor: R.color.colorNeutralPriceChartLine()!
        )

        priceChartRenderer.setSelectedEntry(selectedEntry)
        priceChartRenderer.setDotColor(
            colors.chartHighlightedLineColor,
            shadowColor: colors.entryDotShadowColor
        )

        let finalDataSet = dataBefore.dataSets + dataAfter.dataSets

        rootView.chartView.data = LineChartData(dataSets: finalDataSet)
    }

    func createChartData(
        using entries: [ChartDataEntry],
        lineColor _: UIColor
    ) -> LineChartData {
        let lineDataSet = LineChartDataSet(entries: entries)
        lineDataSet.mode = .cubicBezier
        lineDataSet.drawCirclesEnabled = false
        lineDataSet.lineWidth = 1.5
        lineDataSet.drawValuesEnabled = false

        let lineData = LineChartData(dataSets: [lineDataSet])

        return lineData
    }

    func createColors() -> Colors? {
        guard let widgetViewModel else { return nil }

        return switch widgetViewModel.periodChange {
        case .up:
            Colors(
                chartHighlightedLineColor: R.color.colorPositivePriceChartLine()!,
                entryDotShadowColor: R.color.colorPriceChartPositiveShadow()!,
                changeTextColor: R.color.colorTextPositive()!
            )
        case .down:
            Colors(
                chartHighlightedLineColor: R.color.colorNegativePriceChartLine()!,
                entryDotShadowColor: R.color.colorPriceChartNegativeShadow()!,
                changeTextColor: R.color.colorTextNegative()!
            )
        }
    }
}

// MARK: AssetPriceChartViewProtocol

extension AssetPriceChartViewController: AssetPriceChartViewProtocol {
    func update(with widgetViewModel: AssetPriceChartWidgetViewModel) {
        self.widgetViewModel = widgetViewModel

        updateView()
    }
}

// MARK: ChartViewDelegate

extension AssetPriceChartViewController: ChartViewDelegate {
    func chartValueSelected(
        _: ChartViewBase,
        entry: ChartDataEntry,
        highlight: Highlight
    ) {
        rootView.chartView.highlightValue(highlight)
        updateChart(with: entry)
    }

    func chartValueNothingSelected(_: ChartViewBase) {
        updateChart()
    }
}

// MARK: AssetPriceChartViewProviderProtocol

extension AssetPriceChartViewController: AssetPriceChartViewProviderProtocol {
    func getProposedHeight() -> CGFloat {
        AssetPriceChartViewLayout.Constants.widgetHeight
    }
}

// MARK: Colors

private extension AssetPriceChartViewController {
    struct Colors {
        let chartHighlightedLineColor: UIColor
        let entryDotShadowColor: UIColor
        let changeTextColor: UIColor
    }
}
