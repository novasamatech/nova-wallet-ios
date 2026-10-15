import DGCharts
import UIKit
import UIKit_iOS

protocol SubtensorPriceChartViewDelegate: AnyObject {
    func priceChartViewDidBeginSelection(_ chartView: SubtensorSubnetPriceChartView)
    func priceChartView(_ chartView: SubtensorSubnetPriceChartView, didSelect selection: SubtensorPriceChartSelection)
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
    private var selection: SubtensorPriceChartSelection?
    private var chartData: SubtensorPriceChartData?

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
        static let midLineWidth: CGFloat = 1
        static let midLineDashLengths: [CGFloat] = [3, 3]
        static let fillTopAlpha: CGFloat = 0.28
        static let selectionPressDuration: TimeInterval = 0.05
    }

    var selectionRenderer: AssetPriceChartRenderer? {
        chart.renderer as? AssetPriceChartRenderer
    }

    func plot(viewModel: SubtensorPriceChartViewModel) {
        endSelection()
        plottedWidth = bounds.width
        chartData = SubtensorPriceChartDataFactory.create(
            series: viewModel.series,
            availablePoints: Int(bounds.width)
        )

        guard let chartData else {
            entries = []
            chart.clear()
            return
        }

        chart.xAxis.axisMinimum = chartData.xRange.lowerBound
        chart.xAxis.axisMaximum = chartData.xRange.upperBound
        chart.dragEnabled = isSelectable && chartData.coverage == nil
        chart.highlightPerDragEnabled = chart.dragEnabled
        applyAxis(lower: chartData.yRange.lowerBound, upper: chartData.yRange.upperBound, labels: viewModel.axisLabels)

        let lineColor = viewModel.isRising ? R.color.colorTextPositive()! : R.color.colorTextNegative()!
        self.lineColor = lineColor
        dotShadowColor = viewModel.isRising
            ? R.color.colorPriceChartPositiveShadow()!
            : R.color.colorPriceChartNegativeShadow()!

        entries = chartData.entries.map { entry in
            ChartDataEntry(x: entry.coordinate, y: entry.value, data: entry.sourceIndex)
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
        guide.lineColor = R.color.colorTextTertiary()!
        guide.lineWidth = Constants.midLineWidth
        guide.lineDashLengths = Constants.midLineDashLengths
        guide.drawLabelEnabled = false
        chart.rightAxis.addLimitLine(guide)
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
            let position = entries.firstIndex(where: { $0 === entry }),
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
        guard let selectionRenderer else {
            return
        }

        selectionRenderer.setSelectedEntry(nil, splittedDataSets: nil)
        selectionRenderer.setDotColor(nil, shadowColor: nil)

        chart.highlightValues(nil)
    }

    func selectEntry(_ entry: ChartDataEntry) {
        guard let sourceIndex = entry.data as? Int else {
            return
        }

        applySelection(of: entry)
        notifySelection(.point(sourceIndex: sourceIndex))
    }

    func notifySelection(_ newSelection: SubtensorPriceChartSelection) {
        guard newSelection != selection else {
            return
        }

        selection = newSelection
        delegate?.priceChartView(self, didSelect: newSelection)
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

extension SubtensorSubnetPriceChartView {
    func endSelection() {
        let hadSelection = selection != nil
        selection = nil
        clearSelection()

        if hadSelection {
            delegate?.priceChartViewDidEndSelection(self)
        }
    }

    func highlightEntry(at location: CGPoint) {
        guard isSelectable, let chartData else {
            return
        }

        let coordinate = chart.valueForTouchPoint(point: location, axis: .right).x

        guard let selection = chartData.selection(at: coordinate) else {
            return
        }

        switch selection {
        case let .point(sourceIndex):
            guard let entry = entries.first(where: { ($0.data as? Int) == sourceIndex }) else {
                return
            }

            chart.highlightValue(x: entry.x, y: entry.y, dataSetIndex: 0, callDelegate: false)
            applySelection(of: entry)
        case .noData:
            clearSelection()
        }

        notifySelection(selection)
    }
}

extension SubtensorSubnetPriceChartView: ChartViewDelegate {
    func chartValueSelected(_: ChartViewBase, entry: ChartDataEntry, highlight _: Highlight) {
        guard chartData?.coverage == nil else {
            chart.highlightValues(nil)
            return
        }

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
    var skeletonCornerRadius: CGFloat?

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
        let cornerRadii = skeletonCornerRadius.map { CGSize(width: $0 / size.width, height: $0 / size.height) }

        return [SingleSkeleton.createRow(
            on: self,
            containerView: self,
            spaceSize: size,
            offset: .zero,
            size: size,
            cornerRadii: cornerRadii ?? CGSize(width: 0.5, height: 0.5)
        )]
    }
}
