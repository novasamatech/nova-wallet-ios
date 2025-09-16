import UIKit
import UIKit_iOS
import Kingfisher

final class AssetListTotalBalanceView: UIView {
    private enum Constants {
        static let insets = UIEdgeInsets(top: 13, left: 12, bottom: 12, right: 12)
        static let amountTitleSpacing: CGFloat = 15
        static let cardMotionAngle: CGFloat = 2 * CGFloat.pi / 180
        static let elementMovingMotion: CGFloat = 5
        static let locksContentInsets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        static let infoIconSize = CGSize(width: 12, height: 12)
        static let locksViewHeight: CGFloat = 22.0
    }

    let backgroundBlurView = GladingCardView()

    let displayContentView: UIView = .create { view in
        view.backgroundColor = .clear
    }

    let titleLabel: UILabel = .create { view in
        view.apply(style: .semiboldSubhedlineSecondary)
    }

    let amountLabel: GenericSecuredView<AssetListTotalAmountLabel> = .create { view in
        view.originalView.textColor = R.color.colorTextSecondary()
        view.originalView.font = .boldLargeTitle
    }

    let locksView: GenericSecuredView<AssetListTotalLocksView> = .create {
        $0.isHidden = true
    }

    lazy var sendButton = createActionButton(
        title:
        R.string.localizable.walletSendTitle(preferredLanguages: locale.rLanguages),
        icon: R.image.iconSend()
    )
    lazy var receiveButton = createActionButton(
        title:
        R.string.localizable.walletAssetReceive(preferredLanguages: locale.rLanguages),
        icon: R.image.iconReceive()
    )
    lazy var swapButton = createActionButton(
        title: R.string.localizable.commonSwapAction(
            preferredLanguages: locale.rLanguages
        ),
        icon: R.image.iconActionChange()
    )
    lazy var buySellButton = createActionButton(
        title: R.string.localizable.walletAssetBuySell(
            preferredLanguages: locale.rLanguages
        ),
        icon: R.image.iconBuy()
    )

    lazy var actionsView = UIView.hStack(
        distribution: .fillEqually,
        [
            sendButton,
            receiveButton,
            swapButton,
            buySellButton
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
            amountLabel.bind(value)

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
    }

    private func totalAmountString(from model: AssetListTotalAmountViewModel) -> NSAttributedString {
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorTextPrimary()!,
            .font: UIFont.boldLargeTitle
        ]

        let amount = model.amount

        if
            let lastChar = model.amount.last?.asciiValue,
            !NSCharacterSet.decimalDigits.contains(UnicodeScalar(lastChar)) {
            return .init(string: amount, attributes: defaultAttributes)
        } else {
            guard let decimalSeparator = model.decimalSeparator,
                  let range = amount.range(of: decimalSeparator) else {
                return .init(string: amount, attributes: defaultAttributes)
            }

            let amountAttributedString = NSMutableAttributedString(string: amount)
            let intPartRange = NSRange(amount.startIndex ..< range.lowerBound, in: amount)

            let fractionPartRange = NSRange(range.lowerBound ..< amount.endIndex, in: amount)

            amountAttributedString.setAttributes(
                defaultAttributes,
                range: intPartRange
            )

            amountAttributedString.setAttributes(
                [.foregroundColor: R.color.colorTextSecondary()!,
                 .font: UIFont.boldTitle3],
                range: fractionPartRange
            )

            return amountAttributedString
        }
    }

    private func setupStateWithLocks(amount: SecuredViewModel<String>) {
        locksView.isHidden = false
        locksView.bind(amount)
    }

    private func setupStateWithoutLocks() {
        locksView.isHidden = true
    }

    private func setupLocalization() {
        titleLabel.text = R.string.localizable.walletTotalBalance(
            preferredLanguages: locale.rLanguages
        )
        sendButton.imageWithTitleView?.title = R.string.localizable.walletSendTitle(
            preferredLanguages: locale.rLanguages)
        receiveButton.imageWithTitleView?.title = R.string.localizable.walletAssetReceive(
            preferredLanguages: locale.rLanguages)
        buySellButton.imageWithTitleView?.title = R.string.localizable.walletAssetBuySell(
            preferredLanguages: locale.rLanguages
        )
        swapButton.imageWithTitleView?.title = R.string.localizable.commonSwapAction(
            preferredLanguages: locale.rLanguages
        )
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
