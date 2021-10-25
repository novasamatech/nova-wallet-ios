import UIKit

final class MoonbeamTermsViewLayout: UIView {
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

        let separator = UIView.createSeparator(color: R.color.colorDarkGray())
        let content = UIView.vStack(
            [
                descriptionLabel,
                learnMoreView,
                separator,
                termsView
            ]
        )
        termsView.snp.makeConstraints { $0.height.equalTo(32) }
        learnMoreView.snp.makeConstraints { $0.height.equalTo(48) }
        separator.snp.makeConstraints { $0.height.equalTo(UIConstants.separatorHeight) }

        content.setCustomSpacing(14, after: descriptionLabel)
        content.setCustomSpacing(23, after: separator)

        let scrollView = UIScrollView()
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.bottom.trailing.equalToSuperview()
        }

        let contentView = UIView()
        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(self)
        }

        contentView.addSubview(content)
        content.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(6)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
        }

        addSubview(networkFeeConfirmView)
        networkFeeConfirmView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
        }
    }

    private func applyLocalization() {
        descriptionLabel.text = R.string.localizable
            .crowdloanMoonbeamTermsDescription(preferredLanguages: locale.rLanguages)

        let termsConditions = R.string.localizable.crowdloanTermsValue(preferredLanguages: locale.rLanguages)
        termsLabel.text = R.string.localizable.crowdloanTermsFormat(termsConditions)
        learnMoreView.titleLabel.text = termsConditions
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
