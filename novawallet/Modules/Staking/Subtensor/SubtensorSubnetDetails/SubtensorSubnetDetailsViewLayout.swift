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

    let validatorView = SubtensorValidatorCardView()
    let parametersHeadingLabel = SubtensorSubnetDetailsViewLayout.createSectionLabel()
    let parametersView = SubtensorSubnetParametersView()

    let moreDetailsView = SubtensorSubnetMoreDetailsView()

    let bottomPanel = SubtensorBottomPanelView(style: .solid)

    let favoriteButton: RoundedButton = .create { button in
        button.applyIconWithBackgroundStyle()
        button.roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundSecondary()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorButtonBackgroundSecondary()!
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
        addSubview(bottomPanel)
        bottomPanel.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }

        bottomPanel.contentView.addSubview(favoriteButton)
        favoriteButton.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
            make.size.equalTo(Constants.buttonSize)
        }

        bottomPanel.contentView.addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.equalTo(favoriteButton.snp.trailing).offset(12)
            make.top.trailing.bottom.equalToSuperview()
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomPanel.snp.top)
        }
    }

    func setupPriceWidget() {
        containerView.stackView.addArrangedSubview(priceWidget)
        containerView.stackView.setCustomSpacing(24, after: priceWidget)
    }

    func setupSections() {
        let sections: [(UILabel, UIView)] = [
            (parametersHeadingLabel, parametersView),
            (validatorCaptionLabel, validatorView)
        ]

        sections.forEach { label, view in
            label.snp.makeConstraints { make in
                make.height.greaterThanOrEqualTo(16)
            }

            containerView.stackView.addArrangedSubview(label)
            containerView.stackView.setCustomSpacing(8, after: label)
            containerView.stackView.addArrangedSubview(view)
            containerView.stackView.setCustomSpacing(16, after: view)
        }

        let moreDetailsCard = UIView()
        moreDetailsCard.backgroundColor = R.color.colorBlockBackground()
        moreDetailsCard.layer.cornerRadius = 12
        moreDetailsCard.addSubview(moreDetailsView)

        moreDetailsView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16))
        }

        containerView.stackView.addArrangedSubview(moreDetailsCard)
    }
}
