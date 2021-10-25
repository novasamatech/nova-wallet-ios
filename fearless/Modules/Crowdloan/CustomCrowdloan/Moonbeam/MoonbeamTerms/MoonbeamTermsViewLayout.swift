import UIKit

final class MoonbeamTermsViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.numberOfLines = 0
        return label
    }()

    let termsSwitchView: UISwitch = {
        let switchView = UISwitch()
        switchView.onTintColor = R.color.colorAccent()
        return switchView
    }()

    let termsLabel: UILabel = {
        let label = UILabel()
        label.isUserInteractionEnabled = true
        label.font = .p1Paragraph
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
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        let privacyView = UIView()
        contentView.stackView.addArrangedSubview(privacyView)
        privacyView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
            make.height.equalTo(32)
        }

        privacyView.addSubview(termsSwitchView)
        termsSwitchView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        privacyView.addSubview(termsLabel)
        termsLabel.snp.makeConstraints { make in
            make.leading.equalTo(termsSwitchView.snp.trailing).offset(16.0)
            make.trailing.centerY.equalToSuperview()
        }

        addSubview(networkFeeConfirmView)
        networkFeeConfirmView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
        }
    }

    private func applyLocalization() {
        networkFeeConfirmView.locale = locale
        networkFeeConfirmView.actionButton.imageWithTitleView?.title = termsSwitchView.isOn ?
            "Agree to Terms and Conditions"
            : "Submit agreement"
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        networkFeeConfirmView.networkFeeView.bind(viewModel: feeViewModel)
    }
}
