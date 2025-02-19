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

    lazy var timeRangeControl: UIStackView = .create { view in
        view.axis = .horizontal
        view.spacing = 16
        view.distribution = .fillEqually
    }

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
        addSubview(timeRangeControl)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(16)
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
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.height.equalTo(132)
        }
        timeRangeControl.snp.makeConstraints { make in
            make.top.equalTo(chartView.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.height.equalTo(32)
        }
    }

    func setupChartView() {
        chartView.chartDescription.enabled = false
        chartView.legend.enabled = false
        chartView.leftAxis.enabled = false
        chartView.xAxis.enabled = false
        chartView.setScaleEnabled(false)
        chartView.minOffset = .zero
        chartView.extraTopOffset = .zero
        chartView.extraBottomOffset = .zero
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
        yAxis.setLabelCount(4, force: true)
        yAxis.drawTopYLabelEntryEnabled = true
        yAxis.drawAxisLineEnabled = false
        yAxis.gridLineWidth = 1.5
        yAxis.drawGridLinesEnabled = true
        yAxis.gridColor = R.color.colorChartGridLine()!
        yAxis.gridLineDashLengths = [10.0, 10.0, 0.0]

        chartView.marker = nil
    }
}

// MARK: Constants

extension AssetPriceChartViewLayout {
    enum Constants {
        static let widgetHeight: CGFloat = 292.0
    }
}
