import UIKit
import DGCharts

final class AssetPriceChartViewController: UIViewController, ViewHolder {
    typealias RootViewType = AssetPriceChartViewLayout

    let presenter: AssetPriceChartPresenterProtocol
    let dataSource: AssetPriceChartViewDataSourceProtocol

    init(presenter: AssetPriceChartPresenterProtocol) {
        self.presenter = presenter
        dataSource = AssetPriceChartViewDataSource()
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
        updatePrice()
        updatePriceChange()
        updateChart()
        updatePeriodControlIfNeeded()
    }

    func updatePeriodControlIfNeeded() {
        guard
            let periodControlModel = dataSource.getPeriodControlModel(),
            periodControlModel.periods != rootView.periodControl?.periods
        else { return }

        rootView.setupPeriodControl(with: periodControlModel)
        rootView.periodControl?.delegate = self
    }

    func updateTitle() {
        rootView.titleLabel.text = dataSource.getTitle()
    }

    func updatePrice() {
        guard let currentPrice = dataSource.getCurrentPrice() else { return }

        switch currentPrice {
        case let .cached(text), let .loaded(text):
            rootView.priceLabel.text = text
            rootView.loadingState.remove(.price)
        case .loading:
            rootView.loadingState.formUnion(.price)
        }
    }

    func updatePriceChange() {
        guard
            let periodChange = dataSource.getPeriodChange(),
            let colors = dataSource.createColors()
        else { return }

        var image: UIImage?

        if let value = periodChange.value {
            image = switch value.changeType {
            case .increase:
                R.image.iconFullArrowUp()?.tinted(with: colors.changeTextColor)
            case .decrease:
                R.image.iconFullArrowDown()?.tinted(with: colors.changeTextColor)
            }
        }

        switch periodChange {
        case let .cached(model), let .loaded(model):
            rootView.priceChangeView.detailsLabel.text = model.text
            rootView.priceChangeView.detailsLabel.textColor = colors.changeTextColor
            rootView.priceChangeView.imageView.image = image
            rootView.loadingState.remove(.all)
        case .loading:
            rootView.loadingState.formUnion(.chart)
        }
    }

    func updateChart() {
        guard
            let chartModel = dataSource.getChartModel(),
            let priceChartRenderer = rootView.chartView.renderer as? AssetPriceChartRenderer,
            let colors = dataSource.createColors()
        else { return }

        priceChartRenderer.setSelectedEntry(nil)
        priceChartRenderer.setDotColor(
            nil,
            shadowColor: nil
        )

        switch chartModel {
        case let .cached(model), let .loaded(model):
            let chartData = dataSource.createChartData(
                using: model.dataSet,
                lineColor: colors.chartHighlightedLineColor,
                showHighlighter: false
            )
            rootView.chartView.rightAxis.labelTextColor = R.color.colorTextSecondary()!
            rootView.chartView.data = chartData
            
            /* Clear highlighted indexes to prevent renderer crashes.
               The renderer attempts to highlight indexes from previous datasets,
               which can cause out-of-range errors when switching from multiple
               to single datasets.
               Reference: https://github.com/ChartsOrg/Charts/issues/5154 */
            rootView.chartView.highlightValues(nil)
            rootView.loadingState.remove(.chart)
        case .loading:
            rootView.chartView.rightAxis.labelTextColor = .clear
            rootView.chartView.data = dataSource.createEmptyChartData()
            rootView.loadingState.formUnion(.chart)
        }
    }

    func updateChart(with selectedEntry: ChartDataEntry) {
        guard
            let priceChartRenderer = rootView.chartView.renderer as? AssetPriceChartRenderer,
            let data = dataSource.createChartData(for: selectedEntry),
            let colors = dataSource.createColors()
        else { return }

        priceChartRenderer.setSelectedEntry(selectedEntry)
        priceChartRenderer.setDotColor(
            colors.chartHighlightedLineColor,
            shadowColor: colors.entryDotShadowColor
        )

        rootView.chartView.data = data
    }

    func selectEntry(entry: ChartDataEntry?) {
        guard let entry else {
            presenter.selectEntry(nil)
            return
        }

        let plainEntry = AssetPriceChart.Entry(
            price: Decimal(entry.y),
            timestamp: Int(entry.x)
        )
        presenter.selectEntry(plainEntry)
    }
}

// MARK: AssetPriceChartViewProtocol

extension AssetPriceChartViewController: AssetPriceChartViewProtocol {
    func update(with widgetViewModel: AssetPriceChartWidgetViewModel) {
        dataSource.set(widgetViewModel: widgetViewModel)
        updateView()
    }

    func update(priceChange: PricePeriodChangeViewModel) {
        dataSource.set(priceChange: priceChange)
        updatePriceChange()
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
        selectEntry(entry: entry)
    }

    func chartViewDidEndPanning(_: ChartViewBase) {
        updateChart()
        selectEntry(entry: nil)
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
