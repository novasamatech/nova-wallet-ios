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

        setupChart()
        presenter.setup()
    }
}

// MARK: Private

private extension AssetPriceChartViewController {
    func setupChart() {
        rootView.chartView.delegate = self
    }

    func updateView() {
        updateTitle()
        updateChart()
        updatePeriodControlIfNeeded()
    }

    func updatePeriodControlIfNeeded() {
        guard
            let widgetViewModel,
            widgetViewModel.periodControlModel.periods != rootView.periodControl?.periods
        else { return }

        rootView.setupPeriodControl(with: widgetViewModel.periodControlModel)
        rootView.periodControl?.delegate = self
    }

    func updateTitle() {
        rootView.titleLabel.text = widgetViewModel?.title
    }

    func updatePrice() {
        guard let widgetViewModel else { return }

        switch widgetViewModel.currentPrice {
        case let .cached(text), let .loaded(text):
            rootView.priceLabel.text = text
            rootView.loadingState.remove(.price)
        case .loading:
            rootView.loadingState.formUnion(.price)
        }
    }

    func updatePriceChange() {
        guard
            let widgetViewModel,
            let colors = createColors()
        else { return }

        switch widgetViewModel.periodChange {
        case let .cached(model), let .loaded(model):
            rootView.priceChangeLabel.text = model.value
            rootView.priceChangeLabel.textColor = colors.changeTextColor
            rootView.loadingState.remove(.all)
        case .loading:
            rootView.loadingState.formUnion(.chart)
        }
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

        switch widgetViewModel.chartModel {
        case let .cached(model), let .loaded(model):
            let chartData = createChartData(
                using: model.dataSet,
                lineColor: colors.chartHighlightedLineColor
            )
            rootView.chartView.rightAxis.labelTextColor = R.color.colorTextSecondary()!
            rootView.chartView.data = chartData
            rootView.loadingState.remove(.chart)
        case .loading:
            rootView.chartView.rightAxis.labelTextColor = .clear
            rootView.chartView.data = createEmptyChartData()
            rootView.loadingState.formUnion(.chart)
        }
    }

    func updateChart(with selectedEntry: ChartDataEntry) {
        guard
            let widgetViewModel,
            let chartModel = widgetViewModel.chartModel.value,
            let priceChartRenderer = rootView.chartView.renderer as? AssetPriceChartRenderer,
            let colors = createColors()
        else { return }

        let currentEntries = chartModel.dataSet

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
        lineColor: UIColor
    ) -> LineChartData {
        let lineDataSet = LineChartDataSet(entries: entries)
        lineDataSet.mode = .cubicBezier
        lineDataSet.drawCirclesEnabled = false
        lineDataSet.lineWidth = 1.5
        lineDataSet.drawValuesEnabled = false
        lineDataSet.setColor(lineColor)
        lineDataSet.drawHorizontalHighlightIndicatorEnabled = false
        lineDataSet.drawVerticalHighlightIndicatorEnabled = true
        lineDataSet.highlightEnabled = true
        lineDataSet.highlightColor = R.color.colorNeutralPriceChartLine()!

        let lineData = LineChartData(dataSets: [lineDataSet])

        return lineData
    }

    func createEmptyChartData() -> LineChartData {
        let periods: CGFloat = 2
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

    func createColors() -> Colors? {
        guard let widgetViewModel else { return nil }

        return if let model = widgetViewModel.periodChange.value {
            switch model {
            case .increase:
                Colors(
                    chartHighlightedLineColor: R.color.colorPositivePriceChartLine()!,
                    entryDotShadowColor: R.color.colorPriceChartPositiveShadow()!,
                    changeTextColor: R.color.colorTextPositive()!
                )
            case .decrease:
                Colors(
                    chartHighlightedLineColor: R.color.colorNegativePriceChartLine()!,
                    entryDotShadowColor: R.color.colorPriceChartNegativeShadow()!,
                    changeTextColor: R.color.colorTextNegative()!
                )
            }
        } else {
            Colors(
                chartHighlightedLineColor: R.color.colorNeutralPriceChartLine()!,
                entryDotShadowColor: .clear,
                changeTextColor: R.color.colorTextSecondary()!
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

    func chartViewDidEndPanning(_: ChartViewBase) {
        updateChart()
    }
}

// MARK: PriceChartPeriodControlDelegate

extension AssetPriceChartViewController: PriceChartPeriodControlDelegate {
    func periodControl(
        _: PriceChartPeriodControl,
        didSelect period: PriceChartPeriodViewModel
    ) {
        presenter.selectPeriod(period.period)
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
