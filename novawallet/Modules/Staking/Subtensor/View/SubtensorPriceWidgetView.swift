import UIKit
import UIKit_iOS

final class SubtensorPriceWidgetView: UIView {
    let captionLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
    }

    let priceLabel: UILabel = .create { label in
        label.apply(style: .boldTitle2Primary)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
    }

    let fiatLabel: UILabel = .create { label in
        label.apply(style: .regularSubhedlineSecondary)
    }

    let changeLabel: UILabel = .create { label in
        label.apply(style: .footnotePositive)
    }

    let changeSkeletonView = SubtensorSkeletonView(cornerRadius: 6)

    let dateLabel: UILabel = .create { label in
        label.apply(style: .caption1Secondary)
        label.isHidden = true
    }

    let chartView = SubtensorSubnetPriceChartView(style: .price)

    let chartLoadingView: SubtensorSkeletonView = .create { view in
        view.layer.cornerRadius = Constants.chartCornerRadius
        view.skeletonCornerRadius = Constants.chartCornerRadius
    }

    let chartUnavailableView: SubtensorChartUnavailableView = .create { view in
        view.isHidden = true
    }

    let periodControl: RoundedSegmentedControl = .create { view in
        view.backgroundView.fillColor = .clear
        view.contentInsets = UIEdgeInsets(inset: Constants.periodInset)
        view.selectionCornerRadius = Constants.tabCornerRadius
        view.selectionColor = R.color.colorSegmentedTabActive()!
        view.titleFont = .regularFootnote
        view.selectedTitleColor = R.color.colorTextPrimary()!
        view.titleColor = R.color.colorTextSecondary()!
        view.layoutStrategy = SubtensorSpacedLayoutStrategy(margin: Constants.periodTabInset)
    }

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
        captionLabel.apply(text: viewModel.caption, lineHeight: Constants.footnoteLineHeight)
        priceLabel.apply(text: viewModel.price, lineHeight: Constants.priceLineHeight)
        fiatLabel.text = viewModel.fiat
        fiatLabel.isHidden = viewModel.fiat == nil

        switch viewModel.change {
        case .loading:
            changeLabel.text = nil
            changeSkeletonView.setLoading(true)
        case .hidden:
            changeLabel.text = nil
            changeSkeletonView.setLoading(false)
        case let .value(text, isRising):
            changeLabel.apply(text: text, lineHeight: Constants.footnoteLineHeight)
            changeLabel.textColor = isRising ? R.color.colorTextPositive() : R.color.colorTextNegative()
            changeSkeletonView.setLoading(false)
        }

        dateLabel.isHidden = viewModel.date == nil

        if let date = viewModel.date {
            dateLabel.apply(text: date, lineHeight: Constants.dateLineHeight)
        }
    }
}

private extension SubtensorPriceWidgetView {
    enum Constants {
        static let chartHeight: CGFloat = 208
        static let chartCornerRadius: CGFloat = 16
        static let sectionSpacing: CGFloat = 12
        static let priceSpacing: CGFloat = 4
        static let fiatSpacing: CGFloat = 8
        static let dateSpacing: CGFloat = 4
        static let footnoteLineHeight: CGFloat = 18
        static let priceLineHeight: CGFloat = 28
        static let dateLineHeight: CGFloat = 16
        static let changeSkeletonSize = CGSize(width: 90, height: 12)
        static let tabCornerRadius: CGFloat = 8
        static let periodInset: CGFloat = 4
        static let periodTabInset: CGFloat = 12
        static let periodSize = CGSize(width: 311, height: 32)
        static let disabledAlpha: CGFloat = 0.5
    }

    func bindChartIfNeeded(_ viewModel: SubtensorSubnetChartViewModel) {
        guard viewModel != chartViewModel else {
            return
        }

        chartViewModel = viewModel
        chartLoadingView.setLoading(viewModel == .loading)

        chartView.endSelection()

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
        let periodsView = UIView()
        periodsView.addSubview(periodControl)
        periodControl.snp.makeConstraints { make in
            make.top.bottom.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.width.equalTo(Constants.periodSize.width).priority(.high)
            make.height.equalTo(Constants.periodSize.height)
        }

        let contentView = UIView.vStack(
            spacing: Constants.sectionSpacing,
            [setupHeader(), setupChart(), periodsView]
        )

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(dateLabel)
        dateLabel.snp.makeConstraints { make in
            make.top.equalTo(changeLabel.snp.bottom).offset(Constants.dateSpacing)
            make.leading.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
    }

    func setupHeader() -> UIView {
        let valueView = UIView.hStack(
            alignment: .lastBaseline,
            spacing: Constants.fiatSpacing,
            [priceLabel, fiatLabel, UIView()]
        )

        let headerView = UIView.vStack(
            spacing: Constants.priceSpacing,
            [captionLabel, valueView, changeLabel]
        )

        fiatLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        changeLabel.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Constants.footnoteLineHeight)
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

private final class SubtensorSpacedLayoutStrategy: ListViewLayoutStrategyProtocol {
    let margin: CGFloat

    init(margin: CGFloat) {
        self.margin = margin
    }

    func layout(views: [UIView], in rect: CGRect) {
        let fittingSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: rect.height)
        let widths = views.map { ceil($0.sizeThatFits(fittingSize).width) + 2 * margin }
        let spacing = views.count > 1 ? (rect.width - widths.reduce(0, +)) / CGFloat(views.count - 1) : 0

        var offsetX = rect.minX

        for (view, width) in zip(views, widths) {
            view.frame = CGRect(x: offsetX, y: rect.minY, width: width, height: rect.height)
            offsetX += width + spacing
        }
    }
}
