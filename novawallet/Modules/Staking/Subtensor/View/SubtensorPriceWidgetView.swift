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

    let changeLabel: UILabel = .create { label in
        label.apply(style: .footnotePositive)
    }

    let changeSkeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 6
    }

    let currencyControl: RoundedSegmentedControl = .create { view in
        view.backgroundView.fillColor = R.color.colorSegmentedBackground()!
        view.backgroundView.cornerRadius = Constants.currencyCornerRadius
        view.contentInsets = UIEdgeInsets(inset: Constants.currencyInset)
        view.selectionCornerRadius = Constants.tabCornerRadius
        view.selectionColor = R.color.colorSegmentedTabActive()!
        view.titleFont = .semiBoldFootnote
        view.selectedTitleColor = R.color.colorTextPrimary()!
        view.titleColor = R.color.colorTextSecondary()!
        view.layoutStrategy = SubtensorSpacedLayoutStrategy(margin: Constants.currencyTabInset)
    }

    let chartView: SubtensorSubnetPriceChartView

    let chartLoadingView = SubtensorChartLoadingView()

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

    init(hasHeader: Bool = true) {
        chartView = SubtensorSubnetPriceChartView(style: .price, isSelectable: hasHeader)

        super.init(frame: .zero)

        setupLayout(hasHeader: hasHeader)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorPriceWidgetViewModel) {
        if let header = viewModel.header {
            bind(header: header)
        }

        bindChartIfNeeded(viewModel.chart)
        bind(periods: viewModel.periods)
    }

    func bind(header viewModel: SubtensorSubnetPriceHeaderViewModel) {
        captionLabel.apply(text: viewModel.caption, lineHeight: Constants.footnoteLineHeight)
        priceLabel.apply(text: viewModel.price, lineHeight: Constants.priceLineHeight)

        switch viewModel.change {
        case .loading:
            changeLabel.text = nil
            changeSkeletonView.setLoading(true)
        case .hidden:
            changeLabel.text = nil
            changeSkeletonView.setLoading(false)
        case let .date(text):
            changeLabel.apply(text: text, lineHeight: Constants.footnoteLineHeight)
            changeLabel.textColor = R.color.colorTextSecondary()
            changeSkeletonView.setLoading(false)
        case let .value(text, isRising):
            changeLabel.apply(text: text, lineHeight: Constants.footnoteLineHeight)
            changeLabel.textColor = isRising ? R.color.colorTextPositive() : R.color.colorTextNegative()
            changeSkeletonView.setLoading(false)
        }

        if currencyControl.titles != viewModel.currency.titles {
            currencyControl.titles = viewModel.currency.titles
            updateCurrencyWidth()
        }

        currencyControl.selectedSegmentIndex = viewModel.currency.selectedIndex
        currencyControl.isEnabled = viewModel.currency.isEnabled
    }
}

private extension SubtensorPriceWidgetView {
    enum Constants {
        static let chartHeight: CGFloat = 208
        static let sectionSpacing: CGFloat = 12
        static let headerSpacing: CGFloat = 12
        static let priceSpacing: CGFloat = 4
        static let footnoteLineHeight: CGFloat = 18
        static let priceLineHeight: CGFloat = 28
        static let changeSkeletonSize = CGSize(width: 90, height: 12)
        static let tabCornerRadius: CGFloat = 8
        static let currencyCornerRadius: CGFloat = 10
        static let currencyInset: CGFloat = 2
        static let currencyTabInset: CGFloat = 14
        static let currencyTabSpacing: CGFloat = 2
        static let currencyHeight: CGFloat = 34
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

    func updateCurrencyWidth() {
        let font = currencyControl.titleFont ?? .semiBoldFootnote
        let tabsWidth = currencyControl.titles.reduce(CGFloat(0)) { width, title in
            width + ceil((title as NSString).size(withAttributes: [.font: font]).width) +
                2 * Constants.currencyTabInset
        }
        let spacing = CGFloat(max(currencyControl.numberOfSegments - 1, 0)) * Constants.currencyTabSpacing

        currencyControl.snp.updateConstraints { make in
            make.width.equalTo(tabsWidth + spacing + 2 * Constants.currencyInset)
        }
    }

    func setupLayout(hasHeader: Bool) {
        let periodsView = UIView()
        periodsView.addSubview(periodControl)
        periodControl.snp.makeConstraints { make in
            make.top.bottom.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.width.equalTo(Constants.periodSize.width).priority(.high)
            make.height.equalTo(Constants.periodSize.height)
        }

        let sections = hasHeader
            ? [setupHeader(), setupChart(), periodsView]
            : [setupChart(), periodsView]

        let contentView = UIView.vStack(spacing: Constants.sectionSpacing, sections)

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setupHeader() -> UIView {
        let priceView = UIView.vStack(
            alignment: .leading,
            spacing: Constants.priceSpacing,
            [captionLabel, priceLabel, changeLabel]
        )

        let headerView = UIView.hStack(alignment: .top, spacing: Constants.headerSpacing, [priceView, currencyControl])

        currencyControl.snp.makeConstraints { make in
            make.width.equalTo(0)
            make.height.equalTo(Constants.currencyHeight)
        }

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
