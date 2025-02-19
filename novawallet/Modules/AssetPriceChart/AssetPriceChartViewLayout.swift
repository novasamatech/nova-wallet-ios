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

    lazy var chartView: LineChartView = .create { view in
        configureChartView(view)
    }

    lazy var timeRangeControl: UIStackView = .create { view in
        view.axis = .horizontal
        view.spacing = 16
        view.distribution = .fillEqually
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
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

    func configureChartView(_ chartView: LineChartView) {
        chartView.rightAxis.enabled = false
        chartView.legend.enabled = false
        chartView.pinchZoomEnabled = false
        chartView.doubleTapToZoomEnabled = false

        let yAxis = chartView.rightAxis
        yAxis.labelTextColor = R.color.colorTextSecondary()!
        yAxis.axisLineColor = .clear
        yAxis.gridColor = R.color.colorChartGridLine()!
        yAxis.gridLineDashLengths = [4, 2]
        yAxis.setLabelCount(4, force: false)

        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = R.color.colorTextSecondary()!
        xAxis.axisLineColor = .clear
        xAxis.gridColor = .clear
        xAxis.valueFormatter = DateValueFormatter()
    }

    func createStyledData(
        using entries: [ChartDataEntry],
        overallChangeType: PricePeriodChangeViewModel
    ) -> LineChartData {
        let lineDataSet = LineChartDataSet(entries: entries)
        lineDataSet.mode = .cubicBezier
        lineDataSet.drawCirclesEnabled = false
        lineDataSet.lineWidth = 1.5

        let color = switch overallChangeType {
        case .up:
            R.color.colorPositivePriceChartLine()!
        case .down:
            R.color.colorNegativePriceChartLine()!
        }

        lineDataSet.setColor(color)

        let lineData = LineChartData(dataSets: [lineDataSet])
        lineData.setDrawValues(false)

        return lineData
    }
}

// MARK: Internal

extension AssetPriceChartViewLayout {
    func bind(with widgetViewModel: AssetPriceChartWidgetViewModel) {
        titleLabel.text = widgetViewModel.title
        priceLabel.text = widgetViewModel.currentPrice

        switch widgetViewModel.periodChange {
        case let .up(changeText):
            priceChangeLabel.text = changeText
            priceChangeLabel.textColor = R.color.colorTextPositive()
        case let .down(changeText):
            priceChangeLabel.text = changeText
            priceChangeLabel.textColor = R.color.colorTextNegative()
        }

        let styledData = createStyledData(
            using: widgetViewModel.chartModel.dataSet,
            overallChangeType: widgetViewModel.periodChange
        )

        chartView.data = styledData
    }
}
