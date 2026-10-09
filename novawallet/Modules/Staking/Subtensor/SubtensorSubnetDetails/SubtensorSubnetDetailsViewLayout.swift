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

    let priceWidget = SubtensorPriceWidgetView()

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

    var currencyControl: RoundedSegmentedControl { priceWidget.currencyControl }

    var periodControl: RoundedSegmentedControl { priceWidget.periodControl }

    var chartView: SubtensorSubnetPriceChartView { priceWidget.chartView }

    var chartUnavailableView: SubtensorChartUnavailableView { priceWidget.chartUnavailableView }

    func bind(factorsHeading heading: String?) {
        factorsHeadingLabel.text = heading
        factorsHeadingLabel.alpha = heading == nil ? 0 : 1
        factorsHeadingSkeletonView.setLoading(heading == nil)
    }
}

private extension SubtensorSubnetDetailsViewLayout {
    enum Constants {
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
        setupPriceWidget()
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

    func setupPriceWidget() {
        containerView.stackView.addArrangedSubview(priceWidget)
        containerView.stackView.setCustomSpacing(24, after: priceWidget)
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
