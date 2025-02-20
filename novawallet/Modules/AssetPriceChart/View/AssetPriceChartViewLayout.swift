import UIKit
import DGCharts

final class AssetPriceChartViewLayout: UIView {
    let titleLabel: UILabel = .create { view in
        view.apply(style: .regularSubhedlineSecondary)
    }

    let priceLabel: UILabel = .create { view in
        view.apply(style: .boldTitle3Primary)
    }

    let priceChangeLabel: UILabel = .create { view in
        view.apply(style: .semiboldFootnotePrimary)
    }

    lazy var chartView = LineChartView()

    var periodControl: PriceChartPeriodControl?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupChartView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension AssetPriceChartViewLayout {
    func setupLayout() {
        addSubview(titleLabel)
        addSubview(priceLabel)
        addSubview(priceChangeLabel)
        addSubview(chartView)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview()
        }
        priceLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.equalTo(titleLabel)
        }
        priceChangeLabel.snp.makeConstraints { make in
            make.top.equalTo(priceLabel.snp.bottom).offset(4)
            make.leading.equalTo(priceLabel)
        }
        chartView.snp.makeConstraints { make in
            make.top.equalTo(priceChangeLabel.snp.bottom).offset(8.0)
            make.bottom.equalToSuperview().inset(48)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(132)
        }
    }

    func setupChartView() {
        chartView.chartDescription.enabled = false
        chartView.legend.enabled = false
        chartView.leftAxis.enabled = false
        chartView.xAxis.enabled = false
        chartView.setScaleEnabled(false)
        chartView.minOffset = .zero
        chartView.extraTopOffset = 5.0
        chartView.extraBottomOffset = 5.0
        chartView.pinchZoomEnabled = false
        chartView.doubleTapToZoomEnabled = false

        chartView.renderer = AssetPriceChartRenderer(
            highlightColor: R.color.colorNeutralPriceChartLine()!,
            chart: chartView
        )

        let yAxis = chartView.rightAxis
        yAxis.enabled = true
        yAxis.labelFont = .monospaceNumbers
        yAxis.labelTextColor = R.color.colorTextSecondary()!
        yAxis.setLabelCount(5, force: true)
        yAxis.drawTopYLabelEntryEnabled = true
        yAxis.drawAxisLineEnabled = false
        yAxis.gridLineWidth = 1.5
        yAxis.drawGridLinesEnabled = true
        yAxis.gridColor = R.color.colorChartGridLine()!
        yAxis.gridLineDashLengths = [4.0, 2.0]

        chartView.marker = nil
        chartView.animate(xAxisDuration: 1.5)
    }
}

// MARK: Internal

extension AssetPriceChartViewLayout {
    func setupPeriodControl(with model: PriceChartPeriodControlViewModel) {
        if let periodControl {
            periodControl.removeFromSuperview()
            self.periodControl = nil
        }

        let periodControl = PriceChartPeriodControl(viewModel: model)

        addSubview(periodControl)
        periodControl.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(32)
        }
    }
}

// MARK: Constants

extension AssetPriceChartViewLayout {
    enum Constants {
        static let widgetHeight: CGFloat = 295.0
    }
}
