import DGCharts
import UIKit

final class SubtensorStakingStrategyChartView: UIView {
    private let chartView = LineChartView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupChart()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(values: [Double]) {
        chartView.data = createChartData(values: values)
        chartView.notifyDataSetChanged()
    }

    func animateAppearance() {
        if UIAccessibility.isReduceMotionEnabled {
            chartView.setNeedsDisplay()
        } else {
            chartView.animate(xAxisDuration: Constants.animationDuration)
        }
    }
}

private extension SubtensorStakingStrategyChartView {
    func setupLayout() {
        addSubview(chartView)
        chartView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setupChart() {
        chartView.backgroundColor = .clear
        chartView.chartDescription.enabled = false
        chartView.legend.enabled = false
        chartView.leftAxis.enabled = false
        chartView.rightAxis.enabled = false
        chartView.xAxis.enabled = false
        chartView.setScaleEnabled(false)
        chartView.pinchZoomEnabled = false
        chartView.doubleTapToZoomEnabled = false
        chartView.dragEnabled = false
        chartView.highlightPerTapEnabled = false
        chartView.highlightPerDragEnabled = false
        chartView.minOffset = 0
        chartView.setViewPortOffsets(left: 0, top: 0, right: 0, bottom: 0)

        chartView.leftAxis.axisMinimum = Constants.axisMinimum
        chartView.leftAxis.axisMaximum = Constants.axisMaximum
        chartView.xAxis.axisMinimum = 0
        chartView.xAxis.axisMaximum = Constants.chartWidth
    }

    func createChartData(values: [Double]) -> LineChartData {
        guard let first = values.first, let last = values.last else {
            return LineChartData()
        }

        let entries = values.enumerated().map { index, value in
            ChartDataEntry(x: xValue(for: index, count: values.count), y: value)
        }

        let baseline = createBaselineDataSet(value: first)
        let line = createLineDataSet(entries: entries)
        let start = createEndpointDataSet(
            entry: ChartDataEntry(x: 0, y: first),
            color: UIColor.white.withAlphaComponent(Constants.startPointAlpha)
        )
        let end = createEndpointDataSet(
            entry: ChartDataEntry(x: Constants.chartWidth, y: last),
            color: UIColor.white.withAlphaComponent(Constants.endPointAlpha)
        )

        return LineChartData(dataSets: [baseline, line, start, end])
    }

    func createBaselineDataSet(value: Double) -> LineChartDataSet {
        let dataSet = LineChartDataSet(entries: [
            ChartDataEntry(x: 0, y: value),
            ChartDataEntry(x: Constants.chartWidth, y: value)
        ])
        dataSet.setColor(UIColor.white.withAlphaComponent(Constants.baselineAlpha))
        dataSet.lineWidth = Constants.baselineWidth
        dataSet.lineDashLengths = Constants.baselineDash
        dataSet.drawCirclesEnabled = false
        dataSet.drawValuesEnabled = false
        dataSet.highlightEnabled = false

        return dataSet
    }

    func createLineDataSet(entries: [ChartDataEntry]) -> LineChartDataSet {
        let dataSet = LineChartDataSet(entries: entries)
        dataSet.mode = .linear
        dataSet.setColor(UIColor.white.withAlphaComponent(Constants.lineAlpha))
        dataSet.lineWidth = Constants.lineWidth
        dataSet.drawCirclesEnabled = false
        dataSet.drawValuesEnabled = false
        dataSet.highlightEnabled = false
        dataSet.drawFilledEnabled = true
        dataSet.fillColor = UIColor.white
        dataSet.fillAlpha = Constants.fillAlpha

        return dataSet
    }

    func createEndpointDataSet(entry: ChartDataEntry, color: UIColor) -> LineChartDataSet {
        let dataSet = LineChartDataSet(entries: [entry])
        dataSet.setColor(.clear)
        dataSet.lineWidth = 0
        dataSet.setCircleColor(color)
        dataSet.circleRadius = Constants.pointRadius
        dataSet.drawCircleHoleEnabled = false
        dataSet.drawValuesEnabled = false
        dataSet.highlightEnabled = false

        return dataSet
    }

    func xValue(for index: Int, count: Int) -> Double {
        guard count > 1 else {
            return 0
        }

        return Double(index) * Constants.chartWidth / Double(count - 1)
    }
}

private extension SubtensorStakingStrategyChartView {
    enum Constants {
        static let chartWidth = 303.0
        static let axisMinimum = 0.0
        static let axisMaximum = 140.0
        static let lineWidth: CGFloat = 2.5
        static let baselineWidth: CGFloat = 1
        static let baselineDash: [CGFloat] = [3, 4]
        static let pointRadius: CGFloat = 4
        static let lineAlpha: CGFloat = 0.88
        static let startPointAlpha: CGFloat = 0.6
        static let endPointAlpha: CGFloat = 0.88
        static let baselineAlpha: CGFloat = 0.16
        static let fillAlpha: CGFloat = 0.105412
        static let animationDuration = 1.5
    }
}
