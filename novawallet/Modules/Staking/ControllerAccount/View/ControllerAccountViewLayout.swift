import UIKit

final class ControllerAccountViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.alignment = .fill
        view.stackView.spacing = 0.0
        return view
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let bannerView: GradientBannerView = {
        let view = GradientBannerView()
        view.infoView.imageView.image = R.image.iconBannerShield()
        view.bindGradients(
            left: GradientModel.stakingControllerLeft,
            right: GradientModel.stakingControllerRight
        )

        return view
    }()

    let stashAccountView = WalletAccountInfoView()

    let stashHintView = UIFactory.default.createHintView()

    let controllerAccountView = WalletAccountActionView()

    let controllerHintView = UIFactory.default.createHintView()

    let currentAccountIsControllerHint: HintView = {
        let hintView = HintView()
        hintView.iconView.image = R.image.iconWarning()
        return hintView
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.bottom.trailing.equalToSuperview()
        }

        containerView.stackView.spacing = 16

        containerView.stackView.addArrangedSubview(bannerView)

        containerView.stackView.addArrangedSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        containerView.stackView.addArrangedSubview(stashAccountView)

        containerView.stackView.setCustomSpacing(8, after: stashAccountView)
        containerView.stackView.addArrangedSubview(stashHintView)
        stashHintView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        containerView.stackView.addArrangedSubview(controllerAccountView)

        containerView.stackView.setCustomSpacing(8, after: controllerAccountView)
        containerView.stackView.addArrangedSubview(controllerHintView)
        controllerHintView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(currentAccountIsControllerHint)
        currentAccountIsControllerHint.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(actionButton.snp.top).offset(-UIConstants.horizontalInset)
        }
    }

    private func applyLocalization() {
        bannerView.infoView.titleLabel.text = R.string.localizable.stakingControllerBannerTitle(
            preferredLanguages: locale.rLanguages
        )

        bannerView.infoView.subtitleLabel.text = R.string.localizable.stakingControllerBannerMessage(
            preferredLanguages: locale.rLanguages
        )

        bannerView.linkButton?.imageWithTitleView?.title = R.string.localizable.commonFindMore(
            preferredLanguages: locale.rLanguages
        )

        descriptionLabel.text = R.string.localizable
            .stakingSetSeparateAccountController_v2_2_0(preferredLanguages: locale.rLanguages)
        stashHintView.titleLabel.text = R.string.localizable
            .stakingStashCanHint_v2_2_0(preferredLanguages: locale.rLanguages)
        controllerHintView.titleLabel.text = R.string.localizable
            .stakingControllerCanHint_v2_2_0(preferredLanguages: locale.rLanguages)
        currentAccountIsControllerHint.titleLabel.text = R.string.localizable
            .stakingSwitchAccountToStash(preferredLanguages: locale.rLanguages)
        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
    }
}
