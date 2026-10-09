import UIKit
import UIKit_iOS

final class SubtensorPriceWidgetView: UIView {
    let captionLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
    }

    let priceLabel: UILabel = .create { label in
        label.apply(style: .boldTitle1Primary)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
    }

    let changeLabel: UILabel = .create { label in
        label.apply(style: .footnotePositive)
    }

    let changeSkeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 6
    }

    let currencyControl: RoundedSegmentedControl = SubtensorPriceWidgetView.createSegmentedControl()

    let chartView = SubtensorSubnetPriceChartView(style: .price, isSelectable: true)

    let chartLoadingView = SubtensorChartLoadingView()

    let chartUnavailableView: SubtensorChartUnavailableView = .create { view in
        view.isHidden = true
    }

    let periodControl: RoundedSegmentedControl = SubtensorPriceWidgetView.createSegmentedControl()

    private var chartViewModel: SubtensorSubnetChartViewModel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorPriceWidgetViewModel) {
        bind(header: viewModel.header)
        bindChartIfNeeded(viewModel.chart)
        bind(periods: viewModel.periods)
    }

    func bind(header viewModel: SubtensorSubnetPriceHeaderViewModel) {
        captionLabel.text = viewModel.caption
        priceLabel.text = viewModel.price

        switch viewModel.change {
        case .loading:
            changeLabel.text = nil
            changeSkeletonView.setLoading(true)
        case .hidden:
            changeLabel.text = nil
            changeSkeletonView.setLoading(false)
        case let .value(text, isRising):
            changeLabel.text = text
            changeLabel.textColor = isRising ? R.color.colorTextPositive() : R.color.colorTextNegative()
            changeSkeletonView.setLoading(false)
        }

        currencyControl.isHidden = viewModel.currency == nil

        guard let currency = viewModel.currency else {
            return
        }

        if currencyControl.titles != currency.titles {
            currencyControl.titles = currency.titles
        }

        currencyControl.selectedSegmentIndex = currency.selectedIndex
        currencyControl.isEnabled = currency.isEnabled
    }
}

private extension SubtensorPriceWidgetView {
    enum Constants {
        static let chartHeight: CGFloat = 208
        static let controlHeight: CGFloat = 32
        static let currencyControlWidth: CGFloat = 110
        static let changeMinHeight: CGFloat = 18
        static let changeSkeletonSize = CGSize(width: 90, height: 12)
        static let sectionSpacing: CGFloat = 16
        static let disabledAlpha: CGFloat = 0.4
    }

    static func createSegmentedControl() -> RoundedSegmentedControl {
        .create { view in
            view.backgroundView.fillColor = .clear
            view.selectionColor = R.color.colorSegmentedTabActive()!
            view.titleFont = .regularFootnote
            view.selectedTitleColor = R.color.colorTextPrimary()!
            view.titleColor = R.color.colorTextSecondary()!
        }
    }

    func bindChartIfNeeded(_ viewModel: SubtensorSubnetChartViewModel) {
        guard viewModel != chartViewModel else {
            return
        }

        chartViewModel = viewModel
        chartLoadingView.setLoading(viewModel == .loading)

        switch viewModel {
        case .loading:
            chartView.isHidden = true
            chartUnavailableView.isHidden = true
        case let .chart(chartViewModel):
            chartView.isHidden = false
            chartUnavailableView.isHidden = true
            chartView.bind(viewModel: chartViewModel)
        case let .unavailable(title, details):
            chartView.isHidden = true
            chartUnavailableView.isHidden = false
            chartUnavailableView.bind(title: title, details: details, isAction: false)
        case let .failed(title, action):
            chartView.isHidden = true
            chartUnavailableView.isHidden = false
            chartUnavailableView.bind(title: title, details: action, isAction: true)
        }
    }

    func bind(periods viewModel: SubtensorSubnetPeriodsViewModel) {
        if periodControl.titles != viewModel.titles {
            periodControl.titles = viewModel.titles
        }

        periodControl.selectedSegmentIndex = viewModel.selectedIndex
        periodControl.isEnabled = viewModel.isEnabled
        periodControl.alpha = viewModel.isEnabled ? 1 : Constants.disabledAlpha
    }

    func setupLayout() {
        let headerView = setupHeader()
        let chartContainer = setupChart()

        let contentView = UIView.vStack(
            spacing: Constants.sectionSpacing,
            [headerView, chartContainer, periodControl]
        )

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        periodControl.snp.makeConstraints { make in
            make.height.equalTo(Constants.controlHeight)
        }
    }

    func setupHeader() -> UIView {
        let priceView = UIView.vStack(alignment: .leading, spacing: 4, [captionLabel, priceLabel, changeLabel])
        let headerView = UIView.hStack(alignment: .top, spacing: 16, [priceView, currencyControl])

        currencyControl.snp.makeConstraints { make in
            make.width.equalTo(Constants.currencyControlWidth)
            make.height.equalTo(Constants.controlHeight)
        }

        changeLabel.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Constants.changeMinHeight)
        }

        headerView.addSubview(changeSkeletonView)
        changeSkeletonView.snp.makeConstraints { make in
            make.leading.centerY.equalTo(changeLabel)
            make.size.equalTo(Constants.changeSkeletonSize)
        }

        return headerView
    }

    func setupChart() -> UIView {
        let chartContainer = UIView()

        [chartView, chartLoadingView, chartUnavailableView].forEach { view in
            chartContainer.addSubview(view)
            view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        chartContainer.snp.makeConstraints { make in
            make.height.equalTo(Constants.chartHeight)
        }

        return chartContainer
    }
}
