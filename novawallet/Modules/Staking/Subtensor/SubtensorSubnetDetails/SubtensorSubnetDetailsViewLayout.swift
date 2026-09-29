import UIKit
import UIKit_iOS

final class SubtensorSubnetDetailsViewLayout: UIView {
    let containerView: ScrollableContainerView = .create { view in
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 24, right: 16)
        view.stackView.alignment = .fill
    }

    let titleView: IconDetailsView = .create { view in
        view.detailsLabel.apply(style: .semiboldBodyPrimary)
        view.imageView.contentMode = .scaleAspectFit
        view.iconWidth = 24
        view.spacing = 8
    }

    let priceCaptionLabel: UILabel = .create { label in
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

    let currencyControl: RoundedSegmentedControl = .create { view in
        view.backgroundView.fillColor = .clear
        view.selectionColor = R.color.colorSegmentedTabActive()!
        view.titleFont = .regularFootnote
        view.selectedTitleColor = R.color.colorTextPrimary()!
        view.titleColor = R.color.colorTextSecondary()!
    }

    let chartView = SubtensorSubnetPriceChartView(style: .price)

    let chartLoadingView = SubtensorChartLoadingView()

    let chartUnavailableView: SubtensorChartUnavailableView = .create { view in
        view.isHidden = true
    }

    let periodControl: RoundedSegmentedControl = .create { view in
        view.backgroundView.fillColor = .clear
        view.selectionColor = R.color.colorSegmentedTabActive()!
        view.titleFont = .regularFootnote
        view.selectedTitleColor = R.color.colorTextPrimary()!
        view.titleColor = R.color.colorTextSecondary()!
    }

    let validatorCaptionLabel = SubtensorSubnetDetailsViewLayout.createSectionLabel()

    let validatorView = SubtensorSubnetValidatorRowView()

    let estimateCaptionLabel = SubtensorSubnetDetailsViewLayout.createSectionLabel()

    let estimateView = SubtensorSubnetEstimateView()

    let factorsHeadingLabel = SubtensorSubnetDetailsViewLayout.createSectionLabel()

    let factorsHeadingSkeletonView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = 6
    }

    let factorsView = SubtensorSubnetFactorsView()

    let moreDetailsView = SubtensorSubnetMoreDetailsView()

    let favoriteButton: RoundedButton = .create { button in
        button.applyIconWithBackgroundStyle()
    }

    let actionButton: TriangularedButton = .create { button in
        button.applyDefaultStyle()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(chart viewModel: SubtensorSubnetChartViewModel) {
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
        periodControl.alpha = viewModel.isEnabled ? 1 : 0.4
    }

    func bind(header viewModel: SubtensorSubnetPriceHeaderViewModel) {
        priceCaptionLabel.text = viewModel.caption
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

        if currencyControl.titles != viewModel.currencies {
            currencyControl.titles = viewModel.currencies
        }

        currencyControl.selectedSegmentIndex = viewModel.selectedCurrencyIndex
        currencyControl.isEnabled = viewModel.isCurrencyEnabled
    }

    func bind(factorsHeading heading: String?) {
        factorsHeadingLabel.text = heading
        factorsHeadingLabel.alpha = heading == nil ? 0 : 1
        factorsHeadingSkeletonView.setLoading(heading == nil)
    }
}

private extension SubtensorSubnetDetailsViewLayout {
    enum Constants {
        static let chartHeight: CGFloat = 208
        static let controlHeight: CGFloat = 32
        static let currencyControlWidth: CGFloat = 110
        static let buttonSize: CGFloat = 52
    }

    static func createSectionLabel() -> UILabel {
        .create { label in
            label.apply(style: .semiboldCaps2Secondary)
        }
    }

    func setupLayout() {
        titleView.imageView.snp.makeConstraints { make in
            make.height.equalTo(24)
        }

        setupBottomBar()
        setupHeader()
        setupChart()
        setupSections()
    }

    func setupBottomBar() {
        addSubview(favoriteButton)
        addSubview(actionButton)

        actionButton.snp.makeConstraints { make in
            make.leading.equalTo(favoriteButton.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        favoriteButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(actionButton)
            make.size.equalTo(Constants.buttonSize)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top).offset(-16)
        }
    }

    func setupHeader() {
        let priceView = UIView.vStack(alignment: .leading, spacing: 4, [priceCaptionLabel, priceLabel, changeLabel])
        let headerView = UIView.hStack(alignment: .top, spacing: 16, [priceView, currencyControl])

        currencyControl.snp.makeConstraints { make in
            make.width.equalTo(Constants.currencyControlWidth)
            make.height.equalTo(Constants.controlHeight)
        }

        changeLabel.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(18)
        }

        headerView.addSubview(changeSkeletonView)
        changeSkeletonView.snp.makeConstraints { make in
            make.leading.centerY.equalTo(changeLabel)
            make.size.equalTo(CGSize(width: 90, height: 12))
        }

        containerView.stackView.addArrangedSubview(headerView)
        containerView.stackView.setCustomSpacing(16, after: headerView)
    }

    func setupChart() {
        let chartContainer = UIView()
        chartContainer.addSubview(chartView)
        chartContainer.addSubview(chartLoadingView)
        chartContainer.addSubview(chartUnavailableView)

        [chartView, chartLoadingView, chartUnavailableView].forEach { view in
            view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        chartContainer.snp.makeConstraints { make in
            make.height.equalTo(Constants.chartHeight)
        }

        containerView.stackView.addArrangedSubview(chartContainer)
        containerView.stackView.setCustomSpacing(16, after: chartContainer)

        containerView.stackView.addArrangedSubview(periodControl)
        periodControl.snp.makeConstraints { make in
            make.height.equalTo(Constants.controlHeight)
        }

        containerView.stackView.setCustomSpacing(24, after: periodControl)
    }

    func setupSections() {
        let sections: [(UILabel, UIView)] = [
            (validatorCaptionLabel, validatorView),
            (estimateCaptionLabel, estimateView),
            (factorsHeadingLabel, factorsView)
        ]

        sections.forEach { label, view in
            label.snp.makeConstraints { make in
                make.height.greaterThanOrEqualTo(16)
            }

            containerView.stackView.addArrangedSubview(label)
            containerView.stackView.setCustomSpacing(8, after: label)
            containerView.stackView.addArrangedSubview(view)
            containerView.stackView.setCustomSpacing(24, after: view)
        }

        containerView.stackView.addSubview(factorsHeadingSkeletonView)
        factorsHeadingSkeletonView.snp.makeConstraints { make in
            make.leading.centerY.equalTo(factorsHeadingLabel)
            make.size.equalTo(CGSize(width: 120, height: 10))
        }

        let moreDetailsCard = UIView()
        moreDetailsCard.backgroundColor = R.color.colorBlockBackground()
        moreDetailsCard.layer.cornerRadius = 12
        moreDetailsCard.addSubview(moreDetailsView)

        moreDetailsView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16))
        }

        containerView.stackView.setCustomSpacing(12, after: factorsView)
        containerView.stackView.addArrangedSubview(moreDetailsCard)
    }
}
