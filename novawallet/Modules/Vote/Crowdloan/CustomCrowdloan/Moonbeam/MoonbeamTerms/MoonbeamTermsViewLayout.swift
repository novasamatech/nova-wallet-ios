import UIKit

final class MoonbeamTermsViewLayout: UIView {
    private let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.numberOfLines = 0
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    let termsSwitchView: UISwitch = {
        let switchView = UISwitch()
        switchView.isOn = false
        switchView.onTintColor = R.color.colorAccent()
        return switchView
    }()

    private let termsLabel: UILabel = {
        let label = UILabel()
        label.isUserInteractionEnabled = true
        label.font = .p1Paragraph
        label.textColor = R.color.colorLightGray()
        label.numberOfLines = 2
        return label
    }()

    let learnMoreView = UIFactory.default.createLearnMoreView()

    let networkFeeConfirmView: NetworkFeeConfirmView = UIFactory.default.createNetworkFeeConfirmView()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()
        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        contentView.stackView.addArrangedSubview(learnMoreView)
        contentView.stackView.setCustomSpacing(16, after: descriptionLabel)
        learnMoreView.snp.makeConstraints { make in
            make.width.equalTo(self)
            make.height.equalTo(48)
        }

        let termsView = UIView()
        termsView.addSubview(termsSwitchView)
        termsSwitchView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        termsView.addSubview(termsLabel)
        termsLabel.snp.makeConstraints { make in
            make.leading.equalTo(termsSwitchView.snp.trailing).offset(16)
            make.trailing.centerY.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(termsView)
        termsView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48)
        }

        addSubview(networkFeeConfirmView)
        networkFeeConfirmView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
        }
        contentView.scrollBottomOffset = 170
    }

    private func applyLocalization() {
        descriptionLabel.text = R.string.localizable
            .crowdloanMoonbeamTermsDescription(preferredLanguages: locale.rLanguages)

        let termsConditions = R.string.localizable.crowdloanTermsValue(preferredLanguages: locale.rLanguages)
        termsLabel.text = R.string.localizable
            .crowdloanTermsFormat(termsConditions, preferredLanguages: locale.rLanguages)
        learnMoreView.titleLabel.text = R.string.localizable
            .crowdloanMoonbeamTermsTitle(preferredLanguages: locale.rLanguages)
        networkFeeConfirmView.locale = locale
        updateActionButton()
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        networkFeeConfirmView.networkFeeView.bind(viewModel: feeViewModel)
    }

    func updateActionButton() {
        if termsSwitchView.isOn {
            networkFeeConfirmView.actionButton.imageWithTitleView?.title = R.string.localizable
                .crowdloanSubmitAgreement(preferredLanguages: locale.rLanguages)
            networkFeeConfirmView.actionButton.applyEnabledStyle()
        } else {
            networkFeeConfirmView.actionButton.imageWithTitleView?.title = R.string.localizable
                .karuraTermsAction(preferredLanguages: locale.rLanguages)
            networkFeeConfirmView.actionButton.applyDisabledStyle()
        }
    }
}
