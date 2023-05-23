import UIKit
import SoraUI

final class AssetListTotalBalanceCell: UICollectionViewCell {
    private enum Constants {
        static let insets = UIEdgeInsets(
            top: 12,
            left: 13,
            bottom: 13,
            right: 13
        )

        static let amountY: CGFloat = 50

        static let cardMotionAngle: CGFloat = 2 * CGFloat.pi / 180
        static let elementMovingMotion: CGFloat = 5
        static let locksContentInsets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
    }

    let backgroundBlurView = GladingCardView()

    let displayContentView: UIView = .create { view in
        view.backgroundColor = .clear
    }

    let titleLabel: UILabel = .create { view in
        view.apply(style: .regularSubhedlineSecondary)
    }

    let amountLabel: UILabel = .create { view in
        view.textColor = R.color.colorTextPrimary()
        view.font = .boldLargeTitle
    }

    let locksView: GenericBorderedView<IconDetailsGenericView<IconDetailsView>> = .create {
        $0.contentInsets = Constants.locksContentInsets
        $0.backgroundView.apply(style: .chips)
        $0.setupContentView = { contentView in
            let color = R.color.colorChipText()!
            contentView.imageView.image = R.image.iconBrowserSecurity()?.withTintColor(color)
            contentView.detailsView.detailsLabel.font = .regularFootnote
            contentView.detailsView.detailsLabel.textColor = color
            contentView.spacing = 4
            contentView.detailsView.spacing = 4
            contentView.detailsView.mode = .detailsIcon
            contentView.detailsView.imageView.image = R.image.iconInfoFilled()?.tinted(with: color)
        }

        $0.isHidden = true
    }

    let actionsBackgroundView: BlockBackgroundView = .create { view in
        view.sideLength = 12
    }

    let actionsGladingView: GladingRectView = .create { view in
        view.bind(model: .cardActionsStrokeGlading)
    }

    private var skeletonView: SkrullableView?

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
        setupMotionEffect()
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
            amountLabel.attributedText = totalAmountString(from: value)

            if let lockedAmount = viewModel.locksAmount {
                setupStateWithLocks(amount: lockedAmount)
            } else {
                setupStateWithoutLocks()
            }

            stopLoadingIfNeeded()
        case .loading:
            amountLabel.text = ""
            setupStateWithoutLocks()
            startLoadingIfNeeded()
        }
    }

    private func totalAmountString(from model: AssetListTotalAmountViewModel) -> NSAttributedString {
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorTextPrimary()!,
            .font: UIFont.boldLargeTitle
        ]

        let amount = model.amount
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
             .font: UIFont.boldTitle2],
            range: fractionPartRange
        )

        return amountAttributedString
    }

    private func setupStateWithLocks(amount: String) {
        locksView.isHidden = false

        locksView.contentView.detailsView.detailsLabel.text = amount
    }

    private func setupStateWithoutLocks() {
        locksView.contentView.detailsView.detailsLabel.text = nil
        locksView.isHidden = true
    }

    private func setupLocalization() {
        titleLabel.text = R.string.localizable.walletTotalBalance(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupMotionEffect() {
        setupBackgroundMotion()

        setupMovingMotion(for: displayContentView)
    }

    private func setupBackgroundMotion() {
        let identity = CATransform3DIdentity
        let minimum = CATransform3DRotate(identity, -Constants.cardMotionAngle, 0.0, 1.0, 0.0)
        let maximum = CATransform3DRotate(identity, Constants.cardMotionAngle, 0.0, 1.0, 0.0)

        contentView.layer.transform = identity
        let effect = UIInterpolatingMotionEffect(
            keyPath: "layer.transform",
            type: .tiltAlongHorizontalAxis
        )
        effect.minimumRelativeValue = minimum
        effect.maximumRelativeValue = maximum

        contentView.addMotionEffect(effect)
    }

    private func setupMovingMotion(for view: UIView) {
        let identity = CATransform3DIdentity
        let minimum = CATransform3DTranslate(identity, Constants.elementMovingMotion, 0.0, 0.0)
        let maximum = CATransform3DTranslate(identity, -Constants.elementMovingMotion, 0.0, 0.0)

        view.layer.transform = identity
        let effect = UIInterpolatingMotionEffect(
            keyPath: "layer.transform",
            type: .tiltAlongHorizontalAxis
        )
        effect.minimumRelativeValue = minimum
        effect.maximumRelativeValue = maximum

        view.addMotionEffect(effect)
    }

    private func setupLayout() {
        contentView.addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
        }

        contentView.addSubview(displayContentView)
        displayContentView.snp.makeConstraints { make in
            make.leading.equalTo(backgroundBlurView).offset(Constants.insets.left)
            make.trailing.equalTo(backgroundBlurView).offset(-Constants.insets.right)
            make.top.equalTo(backgroundBlurView).offset(Constants.insets.top)
            make.bottom.equalTo(backgroundBlurView).offset(-Constants.insets.bottom)
        }

        displayContentView.addSubview(locksView)
        locksView.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview()
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
            make.top.equalToSuperview().inset(Constants.amountY - Constants.insets.top)
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
        let spaceSize = contentView.frame.size

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
            contentView.insertSubview(view, aboveSubview: backgroundBlurView)

            skeletonView = view

            view.startSkrulling()

            currentSkeletonView = view
        }

        currentSkeletonView?.frame = CGRect(origin: .zero, size: spaceSize)
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let bigRowSize = CGSize(width: 96.0, height: 16.0)

        let offsetY = Constants.amountY + amountLabel.font.lineHeight / 2.0 -
            bigRowSize.height / 2.0

        let offset = CGPoint(
            x: UIConstants.horizontalInset + Constants.insets.left,
            y: offsetY
        )

        return [
            SingleSkeleton.createRow(
                on: contentView,
                containerView: contentView,
                spaceSize: spaceSize,
                offset: offset,
                size: bigRowSize
            )
        ]
    }
}
