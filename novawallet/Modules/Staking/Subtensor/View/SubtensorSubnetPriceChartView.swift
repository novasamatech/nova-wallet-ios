import DGCharts
import UIKit
import UIKit_iOS

struct SubtensorPriceChartViewModel: Equatable {
    let values: [Double]
    let axisLabels: [String]
    let isRising: Bool
}

protocol SubtensorPriceChartViewDelegate: AnyObject {
    func priceChartViewDidBeginSelection(_ chartView: SubtensorSubnetPriceChartView)
    func priceChartView(_ chartView: SubtensorSubnetPriceChartView, didSelectPointAt index: Int)
    func priceChartViewDidEndSelection(_ chartView: SubtensorSubnetPriceChartView)
}

final class SubtensorSubnetPriceChartView: UIView {
    enum Style {
        case price
        case portfolio
    }

    weak var delegate: SubtensorPriceChartViewDelegate?

    private let chart = LineChartView()
    private let style: Style
    private let isSelectable: Bool

    private var viewModel: SubtensorPriceChartViewModel?
    private var plottedWidth: CGFloat?
    private var entries: [ChartDataEntry] = []
    private var lineColor: UIColor?
    private var dotShadowColor: UIColor?
    private var selectedIndex: Int?

    init(style: Style = .price, isSelectable: Bool = false) {
        self.style = style
        self.isSelectable = isSelectable
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

        if isSelectable {
            setupSelection()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let viewModel, bounds.width != plottedWidth {
            plot(viewModel: viewModel)
        }
    }

    func bind(viewModel: SubtensorPriceChartViewModel) {
        self.viewModel = viewModel
        plot(viewModel: viewModel)
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
        static let selectionPressDuration: TimeInterval = 0.05
    }

    var selectionRenderer: AssetPriceChartRenderer? {
        chart.renderer as? AssetPriceChartRenderer
    }

    func plot(viewModel: SubtensorPriceChartViewModel) {
        clearSelection()
        plottedWidth = bounds.width

        let points = viewModel.values.enumerated().filter(\.element.isFinite)
        let values = points.map(\.element)

        guard values.count > 1, let minimum = values.min(), let maximum = values.max() else {
            entries = []
            chart.clear()
            return
        }

        let padding = maximum > minimum ? 0 : max(abs(maximum) * Constants.flatRangeFactor, Constants.minimumSpread)
        let lower = minimum - padding
        let upper = maximum + padding

        applyAxis(lower: lower, upper: upper, labels: viewModel.axisLabels)

        let lineColor = viewModel.isRising ? R.color.colorTextPositive()! : R.color.colorTextNegative()!
        self.lineColor = lineColor
        dotShadowColor = viewModel.isRising
            ? R.color.colorPriceChartPositiveShadow()!
            : R.color.colorPriceChartNegativeShadow()!

        let availablePoints = Int(bounds.width)
        let plottedPoints = availablePoints > 0 ? points.optimizedForChart(availablePoints: availablePoints) : points

        entries = plottedPoints.map { index, value in
            ChartDataEntry(x: Double(index), y: value)
        }

        applyLine(lineColor: lineColor)
    }

    func setupSelection() {
        chart.renderer = AssetPriceChartRenderer(
            highlightColor: R.color.colorNeutralPriceChartLine()!,
            chart: chart
        )

        chart.delegate = self
        chart.dragEnabled = true
        chart.highlightPerDragEnabled = true
        chart.pinchZoomEnabled = false
        chart.doubleTapToZoomEnabled = false

        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressRecognizer.minimumPressDuration = Constants.selectionPressDuration
        longPressRecognizer.allowableMovement = 0

        chart.addGestureRecognizer(longPressRecognizer)
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

    func createDataSet(entries: [ChartDataEntry], lineColor: UIColor) -> LineChartDataSet {
        let line = LineChartDataSet(entries: entries)
        line.mode = .linear
        line.axisDependency = .right
        line.setColor(lineColor)
        line.lineWidth = Constants.lineWidth
        line.drawCirclesEnabled = false
        line.drawValuesEnabled = false
        line.highlightEnabled = isSelectable
        line.drawHorizontalHighlightIndicatorEnabled = false
        line.drawVerticalHighlightIndicatorEnabled = isSelectable
        line.highlightColor = R.color.colorNeutralPriceChartLine()!

        let fill = fill(for: lineColor)
        line.drawFilledEnabled = fill != nil

        if let fill {
            line.fillAlpha = 1
            line.fill = fill
        }

        return line
    }

    func applyLine(lineColor: UIColor) {
        chart.data = LineChartData(dataSet: createDataSet(entries: entries, lineColor: lineColor))
        chart.notifyDataSetChanged()
    }

    func applySelection(of entry: ChartDataEntry) {
        guard
            let position = entries.firstIndex(where: { $0.x == entry.x }),
            let lineColor,
            let selectionRenderer else {
            return
        }

        let dataSetBefore = createDataSet(entries: Array(entries[...position]), lineColor: lineColor)
        let dataSetAfter = createDataSet(
            entries: Array(entries[position...]),
            lineColor: R.color.colorNeutralPriceChartLine()!
        )

        selectionRenderer.setSelectedEntry(entries[position], splittedDataSets: [dataSetBefore, dataSetAfter])
        selectionRenderer.setDotColor(lineColor, shadowColor: dotShadowColor)

        chart.setNeedsDisplay()
    }

    func clearSelection() {
        selectedIndex = nil

        guard let selectionRenderer else {
            return
        }

        selectionRenderer.setSelectedEntry(nil, splittedDataSets: nil)
        selectionRenderer.setDotColor(nil, shadowColor: nil)

        chart.highlightValues(nil)
    }

    func selectEntry(_ entry: ChartDataEntry) {
        applySelection(of: entry)

        let index = Int(entry.x)

        guard index != selectedIndex else {
            return
        }

        selectedIndex = index
        delegate?.priceChartView(self, didSelectPointAt: index)
    }

    func endSelection() {
        clearSelection()
        delegate?.priceChartViewDidEndSelection(self)
    }

    func highlightEntry(at location: CGPoint) {
        chart.highlightValue(chart.getHighlightByTouchPoint(location), callDelegate: true)
    }

    @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            delegate?.priceChartViewDidBeginSelection(self)
            highlightEntry(at: recognizer.location(in: chart))
        case .changed:
            highlightEntry(at: recognizer.location(in: chart))
        case .ended, .cancelled, .failed:
            endSelection()
        default:
            break
        }
    }
}

extension SubtensorSubnetPriceChartView: ChartViewDelegate {
    func chartValueSelected(_: ChartViewBase, entry: ChartDataEntry, highlight _: Highlight) {
        selectEntry(entry)
    }

    func chartViewDidEndPanning(_: ChartViewBase) {
        endSelection()
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
