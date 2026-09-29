import DGCharts
import UIKit
import UIKit_iOS

struct SubtensorPriceChartViewModel: Equatable {
    let values: [Double]
    let axisLabels: [String]
    let isRising: Bool
}

final class SubtensorSubnetPriceChartView: UIView {
    enum Style {
        case price
        case portfolio
    }

    private let chart = LineChartView()
    private let style: Style

    init(style: Style = .price) {
        self.style = style
        super.init(frame: .zero)
        addSubview(chart)
        chart.snp.makeConstraints { make in make.edges.equalToSuperview() }
        chart.backgroundColor = .clear
        chart.noDataText = ""
        chart.chartDescription.enabled = false
        chart.legend.enabled = false
        chart.leftAxis.enabled = false
        chart.xAxis.enabled = false
        chart.setScaleEnabled(false)
        chart.dragEnabled = false
        chart.highlightPerTapEnabled = false
        chart.minOffset = 0
        chart.extraTopOffset = 8
        chart.extraBottomOffset = 8

        let axis = chart.rightAxis
        axis.enabled = true
        axis.labelFont = .caption1
        axis.labelTextColor = R.color.colorTextSecondary()!
        axis.labelPosition = .outsideChart
        axis.drawAxisLineEnabled = false
        axis.drawGridLinesEnabled = style == .portfolio
        axis.gridColor = R.color.colorChartGridLine()!
        axis.gridLineDashLengths = [2, 3]
        axis.gridLineWidth = 0.5
        axis.setLabelCount(3, force: true)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(viewModel: SubtensorPriceChartViewModel) {
        let values = viewModel.values.filter(\.isFinite)

        guard values.count > 1, let minimum = values.min(), let maximum = values.max() else {
            chart.clear()
            return
        }

        let padding = maximum > minimum ? 0 : max(abs(maximum) * Constants.flatRangeFactor, Constants.minimumSpread)
        let lower = minimum - padding
        let upper = maximum + padding

        applyAxis(lower: lower, upper: upper, labels: viewModel.axisLabels)

        let lineColor = viewModel.isRising ? R.color.colorTextPositive()! : R.color.colorTextNegative()!
        applyLine(values: values, lineColor: lineColor, fill: fill(for: lineColor))
    }
}

private extension SubtensorSubnetPriceChartView {
    enum Constants {
        static let lineWidth: CGFloat = 1.5
        static let midLineWidth: CGFloat = 0.5
        static let midLineDashLengths: [CGFloat] = [2, 3]
        static let fillTopAlpha: CGFloat = 0.28
        static let flatRangeFactor: Double = 0.02
        static let minimumSpread: Double = 1e-6
    }

    func applyAxis(lower: Double, upper: Double, labels: [String]) {
        let axis = chart.rightAxis
        axis.axisMinimum = lower
        axis.axisMaximum = upper
        axis.removeAllLimitLines()

        if style == .price {
            addMidLine(at: (lower + upper) / 2)
        }

        guard labels.count > 1 else {
            axis.drawLabelsEnabled = false
            return
        }

        axis.drawLabelsEnabled = true
        axis.setLabelCount(labels.count, force: true)
        axis.valueFormatter = DefaultAxisValueFormatter { value, _ in
            let position = (upper - value) / (upper - lower) * Double(labels.count - 1)
            let index = min(max(Int(position.rounded()), 0), labels.count - 1)
            return labels[index]
        }
    }

    func addMidLine(at value: Double) {
        let guide = ChartLimitLine(limit: value)
        guide.lineColor = R.color.colorChartGridLine()!
        guide.lineWidth = Constants.midLineWidth
        guide.lineDashLengths = Constants.midLineDashLengths
        guide.drawLabelEnabled = false
        chart.rightAxis.addLimitLine(guide)
        chart.rightAxis.drawLimitLinesBehindDataEnabled = true
    }

    func fill(for lineColor: UIColor) -> Fill? {
        switch style {
        case .price:
            return gradientFill(of: lineColor)
        case .portfolio:
            return ColorFill(color: R.color.colorBlockBackground()!)
        }
    }

    func gradientFill(of color: UIColor) -> Fill? {
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                color.withAlphaComponent(0).cgColor,
                color.withAlphaComponent(Constants.fillTopAlpha).cgColor
            ] as CFArray,
            locations: [0, 1]
        ) else {
            return nil
        }

        return LinearGradientFill(gradient: gradient, angle: 90)
    }

    func applyLine(values: [Double], lineColor: UIColor, fill: Fill?) {
        let entries = values.enumerated().map { index, value in
            ChartDataEntry(x: Double(index), y: value)
        }

        let line = LineChartDataSet(entries: entries)
        line.mode = .linear
        line.axisDependency = .right
        line.setColor(lineColor)
        line.lineWidth = Constants.lineWidth
        line.drawCirclesEnabled = false
        line.drawValuesEnabled = false
        line.highlightEnabled = false
        line.drawFilledEnabled = fill != nil

        if let fill {
            line.fillAlpha = 1
            line.fill = fill
        }

        chart.data = LineChartData(dataSet: line)
        chart.notifyDataSetChanged()
    }
}

final class SubtensorChartLoadingView: UIView, SkeletonableView {
    var skeletonView: SkrullableView?
    var skeletonSuperview: UIView { self }
    var hidingViews: [UIView] { [] }

    private var loading = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 12
        clipsToBounds = true
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if loading { updateLoadingState() }
    }

    func setLoading(_ value: Bool) {
        loading = value
        isHidden = !value
        if value { startLoadingIfNeeded() } else { stopLoadingIfNeeded() }
    }

    func createSkeletons(for size: CGSize) -> [Skeletonable] {
        [SingleSkeleton.createRow(
            on: self,
            containerView: self,
            spaceSize: size,
            offset: .zero,
            size: size
        )]
    }
}
