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

    let bannerView: GradientBannerView = {
        let view = GradientBannerView()
        view.infoView.imageView.image = R.image.iconBannerShield()
        view.bind(model: .stakingController())

        return view
    }()

    let stashAccountView = WalletAccountInfoView()

    let stashHintView = ControllerAccountViewLayout.createMultivalueView()

    let controllerAccountView = WalletAccountActionView()

    let controllerHintView = ControllerAccountViewLayout.createMultivalueView()

    let currentAccountIsControllerHint = InlineAlertView.warning()

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

    func setIsControllerHintShown(_ isShown: Bool) {
        currentAccountIsControllerHint.isHidden = !isShown

        let spacing = isShown ? 16.0 : 24.0
        containerView.stackView.setCustomSpacing(spacing, after: bannerView)
    }

    private func setupLayout() {
        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top).offset(-16.0)
        }

        containerView.stackView.addArrangedSubview(bannerView)
        bannerView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
        }

        containerView.stackView.setCustomSpacing(16.0, after: bannerView)

        containerView.stackView.addArrangedSubview(currentAccountIsControllerHint)
        containerView.stackView.setCustomSpacing(24.0, after: currentAccountIsControllerHint)

        containerView.stackView.addArrangedSubview(stashHintView)
        containerView.stackView.setCustomSpacing(12.0, after: stashHintView)

        containerView.stackView.addArrangedSubview(stashAccountView)
        containerView.stackView.setCustomSpacing(24.0, after: stashAccountView)

        containerView.stackView.addArrangedSubview(controllerHintView)
        containerView.stackView.setCustomSpacing(12.0, after: controllerHintView)

        containerView.stackView.addArrangedSubview(controllerAccountView)
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

        stashHintView.valueTop.text = R.string.localizable.stakingStash(
            preferredLanguages: locale.rLanguages
        )

        stashHintView.valueBottom.text = R.string.localizable.stakingStashCanHint_v2_2_0(
            preferredLanguages: locale.rLanguages
        )

        controllerHintView.valueTop.text = R.string.localizable.stakingController(
            preferredLanguages: locale.rLanguages
        )

        controllerHintView.valueBottom.text = R.string.localizable.stakingControllerCanHint_v2_2_0(
            preferredLanguages: locale.rLanguages
        )

        currentAccountIsControllerHint.contentView.detailsLabel.text = R.string.localizable.stakingSwitchAccountToStash(
            preferredLanguages: locale.rLanguages
        )

        actionButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: locale.rLanguages
        )
    }

    private static func createMultivalueView() -> MultiValueView {
        let view = MultiValueView()
        view.valueTop.textColor = R.color.colorWhite()
        view.valueTop.font = .semiBoldBody
        view.valueTop.numberOfLines = 1
        view.valueBottom.textColor = R.color.colorTransparentText()
        view.valueBottom.font = .regularFootnote
        view.valueBottom.numberOfLines = 0
        view.valueTop.textAlignment = .left
        view.valueBottom.textAlignment = .left
        view.spacing = 4.0
        return view
    }
}
