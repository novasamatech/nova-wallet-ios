import UIKit
import UIKit_iOS

// TODO: Remove
final class WalletSwitchContentView: UIView {
    let typeImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    let iconView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    let badgeView: RoundedView = .create {
        let color = R.color.colorIconAccent()!
        $0.apply(style: .init(
            shadowOpacity: 0,
            fillColor: color,
            highlightedFillColor: color,
            rounding: .init(radius: 5, corners: .allCorners)
        ))
        $0.isHidden = true
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        badgeView.layoutIfNeeded()
        iconView.layoutIfNeeded()

        cutHole(
            on: iconView,
            underView: badgeView,
            holeWidth: 4
        )
    }

    private func setupLayout() {
        addSubview(typeImageView)
        typeImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(20)
        }

        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.width.equalTo(iconView.snp.height)
        }

        addSubview(badgeView)

        badgeView.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview()
            make.width.height.equalTo(10)
        }
    }
}

final class WalletSwitchControl: ControlView<RoundedView, WalletSwitchContentView> {
    private var iconViewModel: ImageViewModelProtocol?

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 80.0, height: 40.0)))
    }

    var typeImageView: UIImageView { controlContentView.typeImageView }

    var iconView: UIImageView { controlContentView.iconView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    func bind(viewModel: WalletSwitchViewModel) {
        iconViewModel?.cancel(on: iconView)

        iconViewModel = viewModel.iconViewModel

        if let iconViewModel = viewModel.iconViewModel {
            let height = preferredHeight ?? frame.height
            let targetSize = CGSize(width: height, height: height)
            iconViewModel.loadImage(on: iconView, targetSize: targetSize, animated: true)
        }

        switch viewModel.type {
        case .secrets:
            controlBackgroundView.fillColor = .clear
            controlBackgroundView.highlightedFillColor = .clear
            controlBackgroundView.strokeColor = .clear
            controlBackgroundView.highlightedStrokeColor = .clear

            typeImageView.image = nil
        case .watchOnly:
            applyCommonStyle(to: controlBackgroundView)

            typeImageView.image = R.image.iconWatchOnly()
        case .paritySigner:
            applyCommonStyle(to: controlBackgroundView)

            typeImageView.image = R.image.iconParitySigner()
        case .polkadotVault:
            applyCommonStyle(to: controlBackgroundView)

            typeImageView.image = R.image.iconPolkadotVault()
        case .ledger:
            applyCommonStyle(to: controlBackgroundView)

            typeImageView.image = R.image.iconLedgerWarning()
        case .proxied:
            applyCommonStyle(to: controlBackgroundView)

            typeImageView.image = R.image.iconProxiedWallet()
        case .genericLedger:
            applyCommonStyle(to: controlBackgroundView)

            typeImageView.image = R.image.iconLedger()
        }

        controlContentView.badgeView.isHidden = !viewModel.hasNotification
        controlContentView.setNeedsLayout()
    }

    private func applyCommonStyle(to backgroundView: RoundedView) {
        backgroundView.apply(style: .chips)
    }

    private func configure() {
        backgroundColor = .clear
        preferredHeight = 40.0
        contentInsets = UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 0.0)

        controlBackgroundView.applyFilledBackgroundStyle()
        controlBackgroundView.fillColor = .clear
        controlBackgroundView.highlightedFillColor = .clear
        controlBackgroundView.strokeColor = .clear
        controlBackgroundView.highlightedStrokeColor = .clear
        controlBackgroundView.strokeWidth = 1.0

        controlBackgroundView.cornerRadius = (preferredHeight ?? 0) / 2.0

        changesContentOpacityWhenHighlighted = true
    }
}

final class WWalletSwitchContentView: UIView {
    enum Constants {
        static let badgeSpacing: CGFloat = 4
        static let typeSpacing: CGFloat = 4
        static let typeSize = CGSize(width: 24, height: 22)
    }

    let titleLabel: UILabel = .create { label in
        label.apply(style: .semiboldCalloutPrimary)
    }

    let typeView: GenericBackgroundView<UIImageView> = .create { view in
        view.apply(style: .chips)
        view.cornerRadius = 8
        view.contentInsets = UIEdgeInsets(verticalInset: 4, horizontalInset: 3)
    }

    let badgeView: RoundedView = .create { view in
        view.apply(style: .badge)
        view.isHidden = true
    }

    let indicatorImageView: UIImageView = .create { view in
        view.image = R.image.iconSmallArrowDown()?.tinted(with: R.color.colorIconSecondary()!)
    }

    override var intrinsicContentSize: CGSize {
        let badgeWidth = !badgeView.isHidden ? 2 * badgeView.cornerRadius + Constants.badgeSpacing : 0
        let badgeHeight = !badgeView.isHidden ? 2 * badgeView.cornerRadius : 0
        let typeWidth = !typeView.isHidden ? Constants.typeSize.width + Constants.typeSpacing : 0
        let typeHeight = !typeView.isHidden ? Constants.typeSize.height : 0

        let titleSize = titleLabel.intrinsicContentSize
        let indicatorSize = indicatorImageView.intrinsicContentSize

        let totalWidth = badgeWidth + typeWidth + titleSize.width + indicatorSize.height
        let totalHeight = [badgeHeight, typeHeight, titleSize.height, indicatorSize.height].max() ?? 0.0

        return CGSize(width: totalWidth, height: totalHeight)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: WWalletSwitchViewModel) {
        titleLabel.text = viewModel.name
        badgeView.isHidden = viewModel.hasNotification ? false : true

        if let typeIcon = viewModel.icon {
            typeView.isHidden = false
            typeView.wrappedView.image = typeIcon
        } else {
            typeView.isHidden = true
            typeView.wrappedView.image = nil
        }

        invalidateIntrinsicContentSize()
    }

    private func setupLayout() {
        let contentView = UIView.hStack(
            alignment: .center,
            distribution: .fill,
            spacing: 0,
            [badgeView, typeView, titleLabel, indicatorImageView]
        )

        contentView.setCustomSpacing(Constants.badgeSpacing, after: badgeView)
        contentView.setCustomSpacing(Constants.typeSpacing, after: typeView)

        addSubview(contentView)

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let badgeSize = 2 * badgeView.cornerRadius

        badgeView.snp.makeConstraints { make in
            make.width.height.equalTo(badgeSize)
        }

        typeView.snp.makeConstraints { make in
            make.size.equalTo(Constants.typeSize)
        }
    }
}

final class WWalletSwitchControl: BackgroundedContentControl {
    let preferredHeight: CGFloat

    var controlContentView: WWalletSwitchContentView! { contentView as? WWalletSwitchContentView }

    var controlBackgroundView: UIView! { backgroundView }

    init() {
        let titleView = WWalletSwitchContentView()

        let backgroundView = UIView()
        backgroundView.isUserInteractionEnabled = false
        backgroundView.backgroundColor = .clear

        preferredHeight = 32.0

        super.init(frame: .zero)

        contentView = titleView
        self.backgroundView = backgroundView

        contentInsets = .zero
    }

    func bind(viewModel: WWalletSwitchViewModel) {
        controlContentView.bind(viewModel: viewModel)

        invalidateIntrinsicContentSize()

        setNeedsLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let width = UIView.layoutFittingExpandedSize.width

        return CGSize(width: width, height: controlContentView.intrinsicContentSize.height)
    }

    override func layoutSubviews() {
        guard let contentView = contentView as? WWalletSwitchContentView else {
            return
        }

        let contentSize = contentView.intrinsicContentSize

        let width = min(bounds.size.width, contentSize.width)

        contentView.frame = CGRect(
            x: bounds.midX - width / 2.0,
            y: bounds.minY,
            width: width,
            height: bounds.height
        )
    }
}
