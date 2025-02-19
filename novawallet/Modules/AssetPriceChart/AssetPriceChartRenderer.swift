import Foundation
import DGCharts

final class AssetPriceChartRenderer: LineChartRenderer {
    private let highlightColor: UIColor

    private var selectedEntry: ChartDataEntry?
    private var dotColor: UIColor?
    private var shadowColor: UIColor?

    init(
        highlightColor: UIColor,
        chart: LineChartView
    ) {
        self.highlightColor = highlightColor

        super.init(
            dataProvider: chart,
            animator: chart.chartAnimator,
            viewPortHandler: chart.viewPortHandler
        )
    }

    func setSelectedEntry(_ entry: ChartDataEntry?) {
        selectedEntry = entry
    }

    func setDotColor(
        _ color: UIColor?,
        shadowColor _: UIColor?
    ) {
        dotColor = color
    }

    override func drawExtras(context: CGContext) {
        super.drawExtras(context: context)

        guard
            let dataProvider = dataProvider,
            let selectedEntry = selectedEntry
        else { return }

        let point = CGPoint(
            x: selectedEntry.x,
            y: selectedEntry.y
        )

        let trans = dataProvider.getTransformer(forAxis: .left)
        let pixelPoint = trans.pixelForValues(x: point.x, y: point.y)

        context.saveGState()
        defer { context.restoreGState() }

        context.setFillColor((shadowColor ?? .clear).cgColor)

        let outerDotRadius: CGFloat = 8.0
        let outerDotRect = CGRect(
            x: pixelPoint.x - outerDotRadius,
            y: pixelPoint.y - outerDotRadius,
            width: outerDotRadius * 2,
            height: outerDotRadius * 2
        )
        context.addEllipse(in: outerDotRect)
        context.fillPath()

        context.setFillColor((dotColor ?? .clear).cgColor)

        let innerDotRadius: CGFloat = 4.0
        let innerDotRect = CGRect(
            x: pixelPoint.x - innerDotRadius,
            y: pixelPoint.y - innerDotRadius,
            width: innerDotRadius * 2,
            height: innerDotRadius * 2
        )
        context.addEllipse(in: innerDotRect)
        context.fillPath()
    }
}
