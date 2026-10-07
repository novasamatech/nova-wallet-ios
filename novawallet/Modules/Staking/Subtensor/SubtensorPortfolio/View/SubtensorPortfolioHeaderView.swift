import UIKit
import UIKit_iOS

final class SubtensorPortfolioHeaderView: UIView {
    let captionLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
    }

    let changeLabel: UILabel = .create { label in
        label.apply(style: .footnotePositive)
        label.textAlignment = .right
    }

    let changeSkeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 6
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
        label.apply(style: .regularBodySecondary)
    }

    let fiatSkeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 6
    }

    let ratesAlertView: InlineAlertView = .create { view in
        view.apply(style: .info)
        view.backgroundView.cornerRadius = 12
        view.contentView.detailsLabel.apply(style: .caption1Secondary)
        view.isHidden = true
    }

    let chartContainerView = UIView()

    let chartView = SubtensorSubnetPriceChartView(style: .portfolio)

    let chartLoadingView = SubtensorChartLoadingView()

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

        bind(fiat: viewModel.fiat, hasTotal: viewModel.total != nil)
        bind(change: viewModel.change)
        bind(chart: viewModel.chart)

        if periodControl.titles != viewModel.periods.titles {
            periodControl.titles = viewModel.periods.titles
        }

        periodControl.selectedSegmentIndex = viewModel.periods.selectedIndex
    }
}

private extension SubtensorPortfolioHeaderView {
    enum Constants {
        static let chartHeight: CGFloat = 120
        static let controlHeight: CGFloat = 32
        static let totalHeight: CGFloat = 34
    }

    func bind(fiat: SubtensorPortfolioLoadable<String>, hasTotal: Bool) {
        switch fiat {
        case .loading:
            fiatLabel.text = nil
            fiatSkeletonView.setLoading(hasTotal)
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
        case .loading:
            changeLabel.text = nil
            changeSkeletonView.setLoading(true)
        case .hidden:
            changeLabel.text = nil
            changeSkeletonView.setLoading(false)
        case let .loaded(viewModel):
            changeLabel.text = viewModel.text
            changeLabel.textColor = viewModel.isRising ? R.color.colorTextPositive() : R.color.colorTextNegative()
            changeSkeletonView.setLoading(false)
        }
    }

    func bind(chart: SubtensorPortfolioChartViewModel) {
        chartContainerView.isHidden = chart == .hidden
        periodControl.isHidden = chart == .hidden

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
        let totalView = UIView.hStack(alignment: .lastBaseline, spacing: 8, [totalLabel, fiatLabel, UIView()])

        [chartView, chartLoadingView, chartUnavailableLabel].forEach { view in
            chartContainerView.addSubview(view)
            view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        let contentView = UIView.vStack(
            spacing: 4,
            [topView, totalView, ratesAlertView, chartContainerView, periodControl]
        )

        contentView.setCustomSpacing(12, after: totalView)
        contentView.setCustomSpacing(12, after: ratesAlertView)
        contentView.setCustomSpacing(12, after: chartContainerView)

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 16, left: 16, bottom: 12, right: 16))
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
        addSubview(changeSkeletonView)
        changeSkeletonView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalTo(captionLabel)
            make.size.equalTo(CGSize(width: 80, height: 12))
        }

        addSubview(totalSkeletonView)
        totalSkeletonView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalTo(totalLabel)
            make.size.equalTo(CGSize(width: 120, height: 24))
        }

        addSubview(fiatSkeletonView)
        fiatSkeletonView.snp.makeConstraints { make in
            make.leading.equalTo(totalLabel.snp.trailing).offset(8)
            make.centerY.equalTo(totalLabel)
            make.size.equalTo(CGSize(width: 72, height: 14))
        }
    }
}
