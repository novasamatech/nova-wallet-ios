import UIKit
import DGCharts
import UIKit_iOS

final class AssetPriceChartViewLayout: UIView {
    var loadingState: LoadingState = .none {
        didSet {
            if loadingState == .none {
                stopLoadingIfNeeded()
            } else {
                startLoadingIfNeeded()
            }
        }
    }

    var skeletonView: SkrullableView?

    let titleLabel: UILabel = .create { view in
        view.apply(style: .regularSubhedlineSecondary)
    }

    let priceLabel: UILabel = .create { view in
        view.apply(style: .boldTitle3Primary)
    }

    let priceChangeView: IconDetailsView = .create { view in
        view.spacing = 0
        view.detailsLabel.apply(style: .semiboldFootnotePrimary)
        view.imageView.contentMode = .scaleAspectFit
    }

    let currentEntryDateLabel: UILabel = .create { view in
        view.apply(style: .footnotePrimary)
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
        addSubview(chartView)

        let priceChangeContainer = UIStackView.hStack(
            spacing: Constants.priceChangeContainerSpacing,
            [
                priceChangeView,
                currentEntryDateLabel
            ]
        )

        addSubview(priceChangeContainer)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview()
            make.height.equalTo(Constants.titleHeight)
        }
        priceLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Constants.priceLabelTopOffset)
            make.leading.equalTo(titleLabel)
        }
        priceChangeContainer.snp.makeConstraints { make in
            make.top.equalTo(priceLabel.snp.bottom).offset(Constants.priceChangeContainerTopOffset)
            make.leading.equalTo(priceLabel)
            make.height.equalTo(Constants.priceChangeViewHeight)
        }
        chartView.snp.makeConstraints { make in
            make.top.equalTo(priceChangeContainer.snp.bottom).offset(Constants.chartViewTopOffset)
            make.bottom.equalToSuperview().inset(Constants.chartViewBottomInset)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.chartViewHeight)
        }
    }

    func setupChartView() {
        chartView.chartDescription.enabled = false
        chartView.legend.enabled = false
        chartView.leftAxis.enabled = false
        chartView.xAxis.enabled = false
        chartView.setScaleEnabled(false)
        chartView.minOffset = .zero
        chartView.extraTopOffset = Constants.chartViewExtraOffsets
        chartView.extraBottomOffset = Constants.chartViewExtraOffsets
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
        yAxis.setLabelCount(Constants.chartYAxisLabelsCount, force: true)
        yAxis.drawTopYLabelEntryEnabled = true
        yAxis.drawAxisLineEnabled = false
        yAxis.gridLineWidth = Constants.gridLineWidth
        yAxis.drawGridLinesEnabled = true
        yAxis.gridColor = R.color.colorChartGridLine()!
        yAxis.gridLineDashLengths = Constants.gridLineDashLengths

        chartView.marker = nil
        chartView.highlightPerTapEnabled = false
        chartView.animate(xAxisDuration: Constants.chartViewAnimationDuration)
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
        self.periodControl = periodControl

        addSubview(periodControl)
        periodControl.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.periodControlHeight)
        }
    }
}

// MARK: Constants

extension AssetPriceChartViewLayout {
    enum Constants {
        static let widgetHeight: CGFloat = 295.0
        static let titleHeight: CGFloat = 20.0
        static let priceChangeViewHeight: CGFloat = 18.0
        static let chartViewHeight: CGFloat = 132.0
        static let gridLineDashLengths: [CGFloat] = [4.0, 2.0]
        static let gridLineWidth: CGFloat = 1.5
        static let periodControlHeight: CGFloat = 32.0

        static let priceChangeContainerSpacing: CGFloat = 4.0

        static let priceChangeContainerTopOffset: CGFloat = 4.0
        static let priceLabelTopOffset: CGFloat = 8.0
        static let chartViewTopOffset: CGFloat = 8.0
        static let chartViewBottomInset: CGFloat = 48.0
        static let chartViewExtraOffsets: CGFloat = 5.0

        static let chartYAxisLabelsCount: Int = 5
        static let chartViewAnimationDuration: CGFloat = 1.5

        static let priceSkeletonOffsets: [CGFloat] = [34.0, 12.0]
        static let priceSkeletonLineWidths: [CGFloat] = [56.0, 126.0]
        static let priceSkeletonLineHeights: [CGFloat] = [16.0, 10.0]

        static let chartSkeletonOffsets: [CGFloat] = [85.0, 24.0, 24.0, 24.0, 24.0]
        static let chartSkeletonLineWidths: [CGFloat] = [22.0, 22.0, 22.0, 22.0, 22.0]
        static let chartSkeletonLineHeights: [CGFloat] = [6.0, 6.0, 6.0, 6.0, 6.0]
    }
}
