import DGCharts
import UIKit
import UIKit_iOS

final class SubtensorSubnetPriceChartView: UIView {
    enum Style {
        case price
        case portfolio
    }

    weak var delegate: SubtensorPriceChartViewDelegate?

    private let chart = LineChartView()
    private let style: Style

    private let referenceView: BorderedLabelView = .create { view in
        view.titleLabel.apply(style: .semiboldCaps1ChartLabel)
        view.backgroundView.fillColor = R.color.colorChartLabelBackground()!
        view.backgroundView.highlightedFillColor = R.color.colorChartLabelBackground()!
        view.backgroundView.cornerRadius = Constants.referenceRadius
        view.contentInsets = Constants.referenceInsets
        view.isUserInteractionEnabled = false
        view.isHidden = true
    }

    private var viewModel: SubtensorPriceChartViewModel?
    private var plottedWidth: CGFloat?
    private var entries: [ChartDataEntry] = []
    private var lineColor: UIColor?
    private var dotShadowColor: UIColor?
    private var selection: SubtensorPriceChartSelection?
    private var chartData: SubtensorPriceChartData?

    init(style: Style = .price) {
        self.style = style
        super.init(frame: .zero)
        addSubview(chart)
        chart.snp.makeConstraints { make in make.edges.equalToSuperview() }
        addSubview(referenceView)
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

        setupSelection()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let viewModel, bounds.width != plottedWidth {
            plot(viewModel: viewModel)
        }

        layoutReference()
    }

    func bind(viewModel: SubtensorPriceChartViewModel) {
        self.viewModel = viewModel
        plot(viewModel: viewModel)
    }
}

private extension SubtensorSubnetPriceChartView {
    enum Constants {
        static let lineWidth: CGFloat = 1.5
        static let guideLineWidth: CGFloat = 1
        static let midLineDashLengths: [CGFloat] = [3, 3]
        static let referenceDashLengths: [CGFloat] = [4, 4]
        static let referenceRadius: CGFloat = 4
        static let referenceInsets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        static let referenceLineHeight: CGFloat = 14
        static let referenceSpacing: CGFloat = 2
        static let fillTopAlpha: CGFloat = 0.28
        static let selectionPressDuration: TimeInterval = 0.05
    }

    var selectionRenderer: AssetPriceChartRenderer? {
        chart.renderer as? AssetPriceChartRenderer
    }

    func plot(viewModel: SubtensorPriceChartViewModel) {
        defer { layoutReference() }

        endSelection()
        plottedWidth = bounds.width
        chartData = SubtensorPriceChartDataFactory.create(
            series: viewModel.series,
            reference: viewModel.reference?.value,
            availablePoints: Int(bounds.width)
        )

        guard let chartData else {
            entries = []
            chart.clear()
            return
        }

        chart.xAxis.axisMinimum = chartData.xRange.lowerBound
        chart.xAxis.axisMaximum = chartData.xRange.upperBound
        chart.dragEnabled = chartData.coverageStart == nil
        chart.highlightPerDragEnabled = chart.dragEnabled
        applyAxis(lower: chartData.yRange.lowerBound, upper: chartData.yRange.upperBound, labels: viewModel.axisLabels)

        if let reference = viewModel.reference {
            addGuide(
                at: reference.value,
                color: R.color.colorTextSecondary()!,
                dashLengths: Constants.referenceDashLengths
            )
            referenceView.titleLabel.apply(text: reference.label, lineHeight: Constants.referenceLineHeight)
        }

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
            addGuide(
                at: (lower + upper) / 2,
                color: R.color.colorTextTertiary()!,
                dashLengths: Constants.midLineDashLengths
            )
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

    func addGuide(at value: Double, color: UIColor, dashLengths: [CGFloat]) {
        let guide = ChartLimitLine(limit: value)
        guide.lineColor = color
        guide.lineWidth = Constants.guideLineWidth
        guide.lineDashLengths = dashLengths
        guide.drawLabelEnabled = false
        chart.rightAxis.addLimitLine(guide)
    }

    func layoutReference() {
        guard let reference = viewModel?.reference, chartData != nil else {
            referenceView.isHidden = true
            return
        }

        let lineY = chart.getTransformer(forAxis: .right).pixelForValues(x: 0, y: reference.value).y
        let size = referenceView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let aboveY = lineY - Constants.referenceSpacing - size.height

        referenceView.frame = CGRect(
            origin: CGPoint(
                x: chart.viewPortHandler.contentRight - size.width,
                y: aboveY < bounds.minY ? lineY + Constants.referenceSpacing : aboveY
            ),
            size: size
        )
        referenceView.isHidden = false
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
        line.drawHorizontalHighlightIndicatorEnabled = false
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
        referenceView.isHidden = true
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
            layoutReference()
            delegate?.priceChartViewDidEndSelection(self)
        }
    }

    func highlightEntry(at location: CGPoint) {
        guard let chartData else {
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
        guard chartData?.coverageStart == nil else {
            chart.highlightValues(nil)
            return
        }

        selectEntry(entry)
    }

    func chartViewDidEndPanning(_: ChartViewBase) {
        endSelection()
    }
}
