import UIKit

final class ControllerAccountViewLayout: ScrollableContainerLayoutView {
    let bannerView: GradientBannerView = .create { view in
        view.infoView.imageView.image = R.image.iconBannerShield()
        view.bind(model: .stakingController())
    }

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

    private var isDeprecated: Bool = false

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

        let spacing = calculateBannerSpacing()

        containerView.stackView.setCustomSpacing(spacing, after: bannerView)
    }

    func applyIsDeprecated(_ isDeprecated: Bool) {
        guard self.isDeprecated != isDeprecated else {
            return
        }

        self.isDeprecated = isDeprecated

        if isDeprecated {
            setupDeprecatedControllerBanner()
        } else {
            setupActualControllerBanner()
        }

        applyBannerLocalization()
        applyActionButtonLocalization()
    }

    private func setupDeprecatedControllerBanner() {
        bannerView.infoView.imageView.image = R.image.iconControllerDeprecated()
        bannerView.bind(model: .criticalUpdate())
    }

    private func setupActualControllerBanner() {
        bannerView.infoView.imageView.image = R.image.iconBannerShield()
        bannerView.bind(model: .stakingController())
    }

    override func setupLayout() {
        super.setupLayout()

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addArrangedSubview(bannerView, spacingAfter: calculateBannerSpacing())

        addArrangedSubview(currentAccountIsControllerHint, spacingAfter: 24)

        addArrangedSubview(stashHintView, spacingAfter: 12)

        addArrangedSubview(stashAccountView, spacingAfter: 24)

        addArrangedSubview(controllerHintView, spacingAfter: 12)

        addArrangedSubview(controllerAccountView)
    }

    private func calculateBannerSpacing() -> CGFloat {
        currentAccountIsControllerHint.isHidden ? 24 : 16
    }

    private func applyLocalization() {
        applyBannerLocalization()

        bannerView.linkButton?.imageWithTitleView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonFindMore()

        stashHintView.valueTop.text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingStash()

        stashHintView.valueBottom.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingStashCanHint_v2_2_0()

        controllerHintView.valueTop.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingController()

        controllerHintView.valueBottom.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingControllerCanHint_v2_2_0()

        currentAccountIsControllerHint.contentView.detailsLabel.text = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSwitchAccountToStash()

        applyActionButtonLocalization()
    }

    private func applyBannerLocalization() {
        if isDeprecated {
            bannerView.infoView.titleLabel.text = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingControllerDeprecatedTitle()

            bannerView.infoView.subtitleLabel.text = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingControllerDeprecatedDetails()
        } else {
            bannerView.infoView.titleLabel.text = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingControllerBannerTitle()

            bannerView.infoView.subtitleLabel.text = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingControllerBannerMessage()
        }
    }

    private func applyActionButtonLocalization() {
        if isDeprecated {
            actionButton.imageWithTitleView?.title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingControllerDeprecatedAction()
        } else {
            actionButton.imageWithTitleView?.title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonContinue()
        }
    }

    private static func createMultivalueView() -> MultiValueView {
        let view = MultiValueView()
        view.valueTop.textColor = R.color.colorTextPrimary()
        view.valueTop.font = .semiBoldBody
        view.valueTop.numberOfLines = 1
        view.valueBottom.textColor = R.color.colorTextSecondary()
        view.valueBottom.font = .regularFootnote
        view.valueBottom.numberOfLines = 0
        view.valueTop.textAlignment = .left
        view.valueBottom.textAlignment = .left
        view.spacing = 4.0
        return view
    }
}
