import UIKit
import DGCharts

final class AssetPriceChartViewLayout: UIView {
    let priceLabel: UILabel = .create { view in
        view.font = .systemFont(ofSize: 28, weight: .bold)
    }
    
    let priceChangeLabel: UILabel = .create { view in
        view.font = .systemFont(ofSize: 14)
    }
    
    let titleLabel: UILabel = .create { view in
        view.font = .systemFont(ofSize: 14)
        view.textColor = .secondaryLabel
    }
    
    lazy var chartView: LineChartView = .create { view in
        configureChartView(view)
    }
    
    lazy var timeRangeStackView: UIStackView = .create { view in
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
        addSubview(timeRangeStackView)
        
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
            make.top.equalTo(priceChangeLabel.snp.bottom).offset(24)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.height.equalTo(200)
        }
        timeRangeStackView.snp.makeConstraints { make in
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
        
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = R.color.colorTextSecondary()!
        xAxis.axisLineColor = .clear
        xAxis.gridColor = .clear
        xAxis.valueFormatter = DateValueFormatter()
    }
}


