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
        label.textColor = R.color.colorTextSecondary()
        return label
    }()

    let termsSwitchView: UISwitch = {
        let switchView = UISwitch()
        switchView.isOn = false
        switchView.onTintColor = R.color.colorIconAccent()
        return switchView
    }()

    private let termsLabel: UILabel = {
        let label = UILabel()
        label.isUserInteractionEnabled = true
        label.font = .p1Paragraph
        label.textColor = R.color.colorTextSecondary()
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

        backgroundColor = R.color.colorSecondaryScreenBackground()
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
        descriptionLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanMoonbeamTermsDescription()

        let termsConditions = R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanTermsValue()
        termsLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanTermsFormat(termsConditions)
        learnMoreView.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanMoonbeamTermsTitle()
        networkFeeConfirmView.locale = locale
        updateActionButton()
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        networkFeeConfirmView.networkFeeView.bind(viewModel: feeViewModel)
    }

    func updateActionButton() {
        if termsSwitchView.isOn {
            networkFeeConfirmView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages).localizable.crowdloanSubmitAgreement()
            networkFeeConfirmView.actionButton.applyEnabledStyle()
        } else {
            networkFeeConfirmView.actionButton.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages).localizable.karuraTermsAction()
            networkFeeConfirmView.actionButton.applyDisabledStyle()
        }
    }
}
