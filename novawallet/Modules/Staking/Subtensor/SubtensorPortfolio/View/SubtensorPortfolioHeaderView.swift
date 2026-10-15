import SnapKit
import UIKit
import UIKit_iOS

final class SubtensorPortfolioHeaderView: UIView {
    let captionLabel: UILabel = .create { label in
        label.font = .regularSubheadline
        label.textColor = R.color.colorTextSecondary()
    }

    let changeLabel: UILabel = .create { label in
        label.apply(style: .semiboldFootnotePositive)
        label.textAlignment = .right
    }

    let totalLabel: UILabel = .create { label in
        label.apply(style: .boldTitle1Primary)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
    }

    let totalSkeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 8
    }

    let fiatLabel: UILabel = .create { label in
        label.font = .regularSubheadline
        label.textColor = R.color.colorTextSecondary()
    }

    let fiatSkeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 7
    }

    let ratesAlertView: InlineAlertView = .create { view in
        view.apply(style: .info)
        view.backgroundView.cornerRadius = 12
        view.contentView.detailsLabel.apply(style: .caption1Secondary)
        view.isHidden = true
    }

    let chartContainerView = UIView()

    let chartView = SubtensorSubnetPriceChartView(style: .portfolio, isSelectable: true)

    let chartLoadingView: SubtensorChartLoadingView = .create { view in
        view.skeletonCornerRadius = 12
    }

    let chartUnavailableLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
        label.textAlignment = .center
        label.numberOfLines = 0
    }

    let periodControl: RoundedSegmentedControl = .create { view in
        view.backgroundView.fillColor = .clear
        view.selectionColor = R.color.colorSegmentedTabActive()!
        view.titleFont = .regularFootnote
        view.selectedTitleColor = R.color.colorTextPrimary()!
        view.titleColor = R.color.colorTextSecondary()!
    }

    private let contentView: UIStackView = .create { view in
        view.axis = .vertical
    }

    private lazy var totalView = UIView.hStack(alignment: .lastBaseline, spacing: 8, [totalLabel, fiatLabel, UIView()])

    private var contentBottomConstraint: Constraint?
    private var chartViewModel: SubtensorPriceChartViewModel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlockBackground()
        layer.cornerRadius = 12

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorPortfolioHeaderViewModel) {
        totalLabel.text = viewModel.total
        totalSkeletonView.setLoading(viewModel.total == nil)

        bind(fiat: viewModel.fiat)
        bind(change: viewModel.change)
        bind(chart: viewModel.chart)

        if periodControl.titles != viewModel.periods.titles {
            periodControl.titles = viewModel.periods.titles
        }

        periodControl.selectedSegmentIndex = viewModel.periods.selectedIndex
    }

    func bind(isRatesUnavailable: Bool) {
        ratesAlertView.isHidden = !isRatesUnavailable
        let spacing = isRatesUnavailable ? Constants.alertSpacing : Constants.chartSpacing
        contentView.setCustomSpacing(spacing, after: totalView)
    }
}

private extension SubtensorPortfolioHeaderView {
    enum Constants {
        static let chartHeight: CGFloat = 120
        static let controlHeight: CGFloat = 32
        static let totalHeight: CGFloat = 34
        static let captionHeight: CGFloat = 20
        static let chartSpacing: CGFloat = 14
        static let alertSpacing: CGFloat = 22
        static let chartSkeletonInset: CGFloat = 12
        static let bottomInset: CGFloat = 12
        static let alertBottomInset: CGFloat = 16
    }

    func bind(fiat: SubtensorPortfolioLoadable<String>) {
        switch fiat {
        case .loading:
            fiatLabel.text = nil
            fiatSkeletonView.setLoading(true)
        case .hidden:
            fiatLabel.text = nil
            fiatSkeletonView.setLoading(false)
        case let .loaded(text):
            fiatLabel.text = text
            fiatSkeletonView.setLoading(false)
        }
    }

    func bind(change: SubtensorPortfolioLoadable<SubtensorPortfolioChangeViewModel>) {
        switch change {
        case .loading, .hidden:
            changeLabel.text = nil
        case let .loaded(viewModel):
            changeLabel.text = viewModel.text
            changeLabel.textColor = viewModel.isRising ? R.color.colorTextPositive() : R.color.colorTextNegative()
        }
    }

    func bind(chart: SubtensorPortfolioChartViewModel) {
        chartContainerView.isHidden = chart == .hidden
        periodControl.isHidden = chart == .hidden
        contentBottomConstraint?.update(inset: chart == .hidden ? Constants.alertBottomInset : Constants.bottomInset)

        switch chart {
        case .loading:
            chartLoadingView.setLoading(true)
            chartView.isHidden = true
            chartUnavailableLabel.isHidden = true
        case let .chart(viewModel):
            chartLoadingView.setLoading(false)
            chartView.isHidden = false
            chartUnavailableLabel.isHidden = true

            if chartViewModel != viewModel {
                chartViewModel = viewModel
                chartView.bind(viewModel: viewModel)
            }
        case let .unavailable(text):
            chartLoadingView.setLoading(false)
            chartView.isHidden = true
            chartUnavailableLabel.isHidden = false
            chartUnavailableLabel.text = text
        case .hidden:
            chartLoadingView.setLoading(false)
            chartView.isHidden = true
            chartUnavailableLabel.isHidden = true
        }
    }

    func setupLayout() {
        let topView = UIView.hStack(alignment: .center, spacing: 8, [captionLabel, UIView(), changeLabel])

        [chartView, chartUnavailableLabel].forEach { view in
            chartContainerView.addSubview(view)
            view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        chartContainerView.addSubview(chartLoadingView)
        chartLoadingView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.chartSkeletonInset)
            make.leading.trailing.bottom.equalToSuperview()
        }

        [topView, totalView, ratesAlertView, chartContainerView, periodControl].forEach(contentView.addArrangedSubview)

        contentView.setCustomSpacing(2, after: topView)
        contentView.setCustomSpacing(Constants.chartSpacing, after: totalView)
        contentView.setCustomSpacing(12, after: ratesAlertView)
        contentView.setCustomSpacing(10, after: chartContainerView)

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(14)
            make.leading.trailing.equalToSuperview().inset(16)
            contentBottomConstraint = make.bottom.equalToSuperview().inset(Constants.bottomInset).constraint
        }

        captionLabel.snp.makeConstraints { make in
            make.height.equalTo(Constants.captionHeight)
        }

        chartContainerView.snp.makeConstraints { make in
            make.height.equalTo(Constants.chartHeight)
        }

        periodControl.snp.makeConstraints { make in
            make.height.equalTo(Constants.controlHeight)
        }

        totalLabel.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Constants.totalHeight)
        }

        totalLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        fiatLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        setupSkeletons()
    }

    func setupSkeletons() {
        addSubview(totalSkeletonView)
        totalSkeletonView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalTo(totalLabel)
            make.size.equalTo(CGSize(width: 120, height: 24))
        }

        addSubview(fiatSkeletonView)
        fiatSkeletonView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.equalTo(totalLabel.snp.bottom)
            make.size.equalTo(CGSize(width: 120, height: 14))
        }
    }
}
