import UIKit
import UIKit_iOS

final class WalletSwitchContentView: UIView {
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
        view.contentInsets = UIEdgeInsets(verticalInset: 3, horizontalInset: 4)
        view.cornerRadius = 7
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

    func bind(viewModel: WalletSwitchViewModel) {
        titleLabel.text = viewModel.name
        badgeView.isHidden = viewModel.hasNotification ? false : true

        if let typeIcon = viewModel.icon {
            typeView.isHidden = false
            typeView.wrappedView.image = typeIcon.tinted(with: R.color.colorIconChip()!)
        } else {
            typeView.isHidden = true
            typeView.wrappedView.image = nil
        }

        invalidateIntrinsicContentSize()
    }

    private func setupLayout() {
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        indicatorImageView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        typeView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        badgeView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

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

final class WalletSwitchControl: BackgroundedContentControl {
    let preferredHeight: CGFloat

    var controlContentView: WalletSwitchContentView! { contentView as? WalletSwitchContentView }

    var controlBackgroundView: UIView! { backgroundView }

    init() {
        let titleView = WalletSwitchContentView()

        titleView.isUserInteractionEnabled = false

        let backgroundView = UIView()
        backgroundView.isUserInteractionEnabled = false
        backgroundView.backgroundColor = .clear

        preferredHeight = 32.0

        super.init(frame: .zero)

        contentView = titleView
        self.backgroundView = backgroundView

        contentInsets = .zero

        changesContentOpacityWhenHighlighted = true
    }

    func bind(viewModel: WalletSwitchViewModel) {
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
        guard let contentView = contentView as? WalletSwitchContentView else {
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
