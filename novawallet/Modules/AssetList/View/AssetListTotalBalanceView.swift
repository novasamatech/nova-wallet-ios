import UIKit
import UIKit_iOS
import Kingfisher
import Lottie

final class AssetListTotalBalanceView: UIView {
    let backgroundBlurView = GladingFrostedCardView()

    let lottieAnimationView: LottieAnimationView = .create { view in
        view.animation = snowfallAnimation
        view.loopMode = .loop
        view.contentMode = .scaleAspectFill
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.configuration = .init(renderingEngine: .coreAnimation)
        view.animationSpeed = 0.5
    }

    let displayContentView: UIView = .create { view in
        view.backgroundColor = .clear
    }

    let titleLabel: UILabel = .create { view in
        view.apply(style: .semiboldSubhedlineSecondary)
    }

    let privacyToggleButton: UIButton = .create { button in
        button.imageView?.contentMode = .scaleAspectFit
    }

    let amountLabel: DotsSecureView<AssetListTotalAmountLabel> = .create { view in
        view.privacyModeConfiguration = .largeBalanceChip
        view.preferredSecuredHeight = Constants.totalBalanceSecureHeight
        view.originalView.textColor = R.color.colorTextSecondary()
        view.originalView.font = .boldLargeTitle
    }

    let locksView: GenericBorderedView<
        IconDetailsGenericView<
            IconDetailsGenericView<
                DotsSecureView<UILabel>
            >
        >
    > = .create {
        $0.contentInsets = Constants.locksContentInsets
        $0.backgroundView.apply(style: .chipsOnCard)
        $0.setupContentView = { contentView in
            contentView.imageView.image = R.image.iconBrowserSecurity()?.withTintColor(R.color.colorIconChip()!)
            contentView.detailsView.detailsView.privacyModeConfiguration = .smallBalanceChip
            contentView.detailsView.detailsView.preferredSecuredHeight = Constants.locksSecureViewHeight
            contentView.detailsView.detailsView.originalView.font = .regularFootnote
            contentView.detailsView.detailsView.originalView.textColor = R.color.colorChipText()!
            contentView.spacing = 4
            contentView.detailsView.spacing = 4
            contentView.detailsView.mode = .detailsIcon
            contentView.detailsView.imageView.image = R.image.iconInfoFilled()?.kf.resize(to: Constants.infoIconSize)
        }

        $0.isHidden = true
    }

    lazy var sendButton = createActionButton(
        title:
        R.string(preferredLanguages: locale.rLanguages).localizable.walletSendTitle(),
        icon: R.image.iconSend()
    )
    lazy var receiveButton = createActionButton(
        title:
        R.string(preferredLanguages: locale.rLanguages).localizable.walletAssetReceive(),
        icon: R.image.iconReceive()
    )
    lazy var swapButton = createActionButton(
        title: R.string(preferredLanguages: locale.rLanguages).localizable.commonSwapAction(),
        icon: R.image.iconActionChange()
    )
    lazy var buySellButton = createActionButton(
        title: R.string(preferredLanguages: locale.rLanguages).localizable.walletAssetBuySell(),
        icon: R.image.iconBuy()
    )
    lazy var giftButton = createActionButton(
        title: R.string(preferredLanguages: locale.rLanguages).localizable.commonGift(),
        icon: R.image.iconGift()
    )

    lazy var actionsView = UIView.hStack(
        distribution: .fillEqually,
        [
            sendButton,
            receiveButton,
            swapButton,
            buySellButton,
            giftButton
        ]
    )

    let actionsBackgroundView: OverlayBlurBackgroundView = .create { view in
        view.sideLength = 12
        view.borderType = .none
        view.overlayView.fillColor = R.color.colorBlockBackground()!
        view.overlayView.strokeColor = R.color.colorCardActionsBorder()!
        view.overlayView.strokeWidth = 1
        view.blurView?.alpha = 0.5
    }

    let actionsGladingView: GladingRectView = .create { view in
        view.bind(model: .cardActionsStrokeGlading)
    }

    private var skeletonView: SkrullableView?
    private var shadowView1: RoundedView = .create { view in
        view.cornerRadius = 12
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.shadowColor = UIColor.black
        view.shadowOpacity = 0.16
        view.shadowOffset = CGSize(width: 6, height: 4)
    }

    private var shadowView2: RoundedView = .create { view in
        view.cornerRadius = 12
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.shadowColor = UIColor.black
        view.shadowOpacity = 0.25
        view.shadowOffset = CGSize(width: 2, height: 4)
    }

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupLocalization()
        setupAnimation()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if skeletonView != nil {
            setupSkeleton()
        }
    }

    func bind(viewModel: AssetListHeaderViewModel) {
        switch viewModel.amount {
        case let .loaded(value), let .cached(value):
            amountLabel.originalView.bind(value.originalContent)
            amountLabel.bind(value.privacyMode)

            if let lockedAmount = viewModel.locksAmount {
                setupStateWithLocks(amount: lockedAmount)
            } else {
                setupStateWithoutLocks()
            }

            stopLoadingIfNeeded()
        case .loading:
            amountLabel.originalView.text = ""
            setupStateWithoutLocks()
            startLoadingIfNeeded()
        }

        swapButton.isEnabled = viewModel.hasSwaps

        setupPrivacyModeToggle(enabled: viewModel.privacyModelEnabled)
    }

    private func setupPrivacyModeToggle(enabled: Bool) {
        let icon = enabled ? R.image.iconEyeHide() : R.image.iconEyeShow()

        privacyToggleButton.setImage(
            icon,
            for: .normal
        )
        privacyToggleButton.setImage(
            icon?.withTintColor(
                R.color.colorIconSecondary()!.withAlphaComponent(0.5)
            ),
            for: .highlighted
        )
    }

    private func setupStateWithLocks(amount: SecuredViewModel<String>) {
        locksView.isHidden = false
        locksView.contentView.detailsView.detailsView.originalView.text = amount.originalContent
        locksView.contentView.detailsView.detailsView.bind(amount.privacyMode)
    }

    private func setupStateWithoutLocks() {
        locksView.isHidden = true
    }

    private func setupLocalization() {
        titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.walletTotalBalance()
        sendButton.imageWithTitleView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.walletSendTitle()
        receiveButton.imageWithTitleView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.walletAssetReceive()
        buySellButton.imageWithTitleView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.walletAssetBuySell()
        swapButton.imageWithTitleView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonSwapAction()
        giftButton.imageWithTitleView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonGift()
    }

    private func setupLayout() {
        [shadowView1, shadowView2].forEach { view in
            addSubview(view)

            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.top.bottom.equalToSuperview()
            }
        }

        addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview()
        }

        backgroundBlurView.addSubview(lottieAnimationView)
        lottieAnimationView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(displayContentView)
        displayContentView.snp.makeConstraints { make in
            make.leading.equalTo(backgroundBlurView).offset(Constants.insets.left)
            make.trailing.equalTo(backgroundBlurView).offset(-Constants.insets.right)
            make.top.equalTo(backgroundBlurView).offset(Constants.insets.top)
            make.bottom.equalTo(backgroundBlurView).offset(-Constants.insets.bottom)
        }

        displayContentView.addSubview(locksView)
        locksView.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview()
            make.height.equalTo(Constants.locksViewHeight)
        }

        displayContentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalTo(locksView.snp.centerY)
            make.trailing.lessThanOrEqualTo(locksView.snp.leading).offset(-8)
        }

        displayContentView.addSubview(privacyToggleButton)
        privacyToggleButton.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.leading.equalTo(titleLabel.snp.trailing).offset(8)
            make.size.equalTo(Constants.privacyButtonSize)
        }

        displayContentView.addSubview(amountLabel)
        amountLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(Constants.amountTitleSpacing)
        }

        displayContentView.addSubview(actionsBackgroundView)
        actionsBackgroundView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.size.height.equalTo(80)
        }

        actionsBackgroundView.addSubview(actionsGladingView)
        actionsGladingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        actionsBackgroundView.addSubview(actionsView)
        actionsView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setupAnimation() {
        lottieAnimationView.stop()
        lottieAnimationView.play()
    }

    func startLoadingIfNeeded() {
        guard skeletonView == nil else {
            return
        }

        amountLabel.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        amountLabel.alpha = 1.0
    }

    private func setupSkeleton() {
        let spaceSize = frame.size

        guard spaceSize.width > 0, spaceSize.height > 0 else {
            return
        }

        let builder = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: createSkeletons(for: spaceSize)
        )

        let currentSkeletonView: SkrullableView?

        if let skeletonView = skeletonView {
            currentSkeletonView = skeletonView
            builder.updateSkeletons(in: skeletonView)
        } else {
            let view = builder
                .fillSkeletonStart(R.color.colorSkeletonStart()!)
                .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
                .build()
            view.autoresizingMask = []
            insertSubview(view, aboveSubview: backgroundBlurView)

            skeletonView = view

            view.startSkrulling()

            currentSkeletonView = view
        }

        currentSkeletonView?.frame = CGRect(origin: .zero, size: spaceSize)
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let bigRowSize = CGSize(width: 96.0, height: 16.0)

        let offsetY = Constants.insets.top
            + titleLabel.font.lineHeight
            + Constants.amountTitleSpacing
            + amountLabel.originalView.font.lineHeight / 2.0 - bigRowSize.height / 2.0

        let offset = CGPoint(
            x: UIConstants.horizontalInset + Constants.insets.left,
            y: offsetY
        )

        return [
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: offset,
                size: bigRowSize
            )
        ]
    }

    private func createActionButton(title: String?, icon: UIImage?) -> RoundedButton {
        let button = RoundedButton()
        button.roundedBackgroundView?.fillColor = .clear
        button.roundedBackgroundView?.highlightedFillColor = .clear
        button.roundedBackgroundView?.strokeColor = .clear
        button.roundedBackgroundView?.highlightedStrokeColor = .clear
        button.roundedBackgroundView?.shadowOpacity = 0
        button.roundedBackgroundView?.cornerRadius = 0
        button.imageWithTitleView?.title = title
        button.imageWithTitleView?.iconImage = icon
        button.imageWithTitleView?.layoutType = .verticalImageFirst
        button.imageWithTitleView?.spacingBetweenLabelAndIcon = 8
        button.imageWithTitleView?.titleColor = R.color.colorTextPrimary()
        button.imageWithTitleView?.titleFont = .semiBoldCaption1
        button.contentOpacityWhenHighlighted = 0.2
        button.changesContentOpacityWhenHighlighted = true
        return button
    }
}

extension AssetListTotalBalanceView: AnimationUpdatibleView {
    func updateLayerAnimationIfActive() {
        backgroundBlurView.updateLayerAnimationIfActive()
        actionsGladingView.updateLayerAnimationIfActive()

        skeletonView?.restartSkrulling()
    }
}

// MARK: - Constants

private extension AssetListTotalBalanceView {
    enum Constants {
        static let insets = UIEdgeInsets(top: 13, left: 12, bottom: 12, right: 12)
        static let amountTitleSpacing: CGFloat = 15
        static let cardMotionAngle: CGFloat = 2 * CGFloat.pi / 180
        static let elementMovingMotion: CGFloat = 5
        static let locksContentInsets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        static let infoIconSize = CGSize(width: 12, height: 12)
        static let locksSecureViewHeight: CGFloat = 15.0
        static let locksViewHeight: CGFloat = 22.0
        static let privacyButtonSize = CGSize(width: 20, height: 20)
        static let totalBalanceSecureHeight: CGFloat = 47.0
    }

    static let snowfallAnimation: LottieAnimation? = LottieAnimation.named(
        "snowfall",
        bundle: .main
    )
}
