import SnapKit
import UIKit
import UIKit_iOS

final class SubtensorSubnetCell: UITableViewCell {
    static let preferredHeight: CGFloat = 60
    static let unfavoriteImage = R.image.iconFavToolbar()?.tinted(with: R.color.colorIconSecondary()!)

    let iconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = Constants.iconSize / 2
        view.clipsToBounds = true
    }

    let titleLabel: UILabel = .create { view in
        view.apply(style: .semiboldSubhedlinePrimary)
        view.lineBreakMode = .byTruncatingTail
    }

    let subtitleLabel: UILabel = .create { view in
        view.apply(style: .caption1Secondary)
        view.lineBreakMode = .byTruncatingTail
    }

    let priceLabel: UILabel = .create { view in
        view.apply(style: .semiboldFootnotePrimary)
        view.textAlignment = .right
    }

    let changeLabel: UILabel = .create { view in
        view.apply(style: .caption1Secondary)
        view.textAlignment = .right
    }

    let sparklineView = SubtensorSparklineView()

    let changeLoadingView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = Constants.changePlaceholderSize.height / 2
    }

    let sparklineLoadingView: SubtensorChartLoadingView = .create { view in
        view.layer.cornerRadius = Constants.sparklinePlaceholderSize.height / 2
    }

    let favoriteButton: UIButton = .create { view in
        view.imageView?.contentMode = .scaleAspectFit
    }

    let dividerView: UIView = .create { view in
        view.backgroundColor = R.color.colorDivider()
    }

    var favoriteAction: (() -> Void)?

    private var iconViewModel: ImageViewModelProtocol?
    private var sparklineWidthConstraint: Constraint?
    private var valuesTrailingConstraint: Constraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellBackgroundPressed()

        favoriteButton.addTarget(self, action: #selector(actionFavorite), for: .touchUpInside)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        favoriteAction = nil
        iconViewModel?.cancel(on: iconView)
        iconViewModel = nil
        iconView.image = nil
    }

    func bind(viewModel: SubtensorSubnetSelectViewModel) {
        iconViewModel?.cancel(on: iconView)
        iconViewModel = viewModel.icon

        viewModel.icon.loadImage(
            on: iconView,
            targetSize: CGSize(width: Constants.iconSize, height: Constants.iconSize),
            animated: true
        )

        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        subtitleLabel.isHidden = viewModel.subtitle == nil

        priceLabel.text = viewModel.price

        bind(change: viewModel.change)

        favoriteButton.setImage(
            viewModel.isFavorite ? R.image.iconFavToolbarSel() : Self.unfavoriteImage,
            for: .normal
        )

        favoriteButton.accessibilityLabel = viewModel.favoriteAccessibilityLabel
        favoriteButton.accessibilityValue = viewModel.favoriteAccessibilityValue
    }
}

private extension SubtensorSubnetCell {
    func bind(change: SubtensorSubnetSelectViewModel.Change) {
        switch change {
        case .loading:
            changeLabel.text = nil
            sparklineView.clear()
            setChangeLoading(true)
            setSparklineSlot(isVisible: true)
        case let .value(text, isRising, sparkline):
            changeLabel.text = text
            changeLabel.textColor = isRising ? R.color.colorTextPositive() : R.color.colorTextNegative()
            sparklineView.bind(values: sparkline, isRising: isRising)
            setChangeLoading(false)
            setSparklineSlot(isVisible: true)
        case let .unavailable(text):
            changeLabel.text = text
            changeLabel.textColor = R.color.colorTextSecondary()
            sparklineView.clear()
            setChangeLoading(false)
            setSparklineSlot(isVisible: true)
        case let .notListed(text):
            changeLabel.text = text
            changeLabel.textColor = R.color.colorTextSecondary()
            sparklineView.clear()
            setChangeLoading(false)
            setSparklineSlot(isVisible: false)
        }
    }

    func setSparklineSlot(isVisible: Bool) {
        sparklineWidthConstraint?.update(offset: isVisible ? Constants.sparklineSize.width : 0)
        valuesTrailingConstraint?.update(offset: isVisible ? -Constants.contentSpacing : 0)
    }

    func setChangeLoading(_ isLoading: Bool) {
        changeLoadingView.setLoading(isLoading)
        sparklineLoadingView.setLoading(isLoading)
    }

    @objc func actionFavorite() {
        favoriteAction?()
    }

    func setupLayout() {
        let labelsView = UIView.vStack(alignment: .leading, spacing: Constants.labelsSpacing, [
            titleLabel,
            subtitleLabel
        ])

        let valuesView = UIView.vStack(alignment: .trailing, spacing: Constants.labelsSpacing, [
            priceLabel,
            changeLabel
        ])

        [
            iconView,
            labelsView,
            valuesView,
            sparklineView,
            changeLoadingView,
            sparklineLoadingView,
            favoriteButton,
            dividerView
        ].forEach(contentView.addSubview)

        setupEdgesLayout()
        setupValuesLayout(labelsView: labelsView, valuesView: valuesView)
    }

    func setupEdgesLayout() {
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.contentInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        favoriteButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Constants.contentInset - Constants.favoriteTouchOutset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.favoriteSize + 2 * Constants.favoriteTouchOutset)
        }

        sparklineView.snp.makeConstraints { make in
            make.trailing.equalTo(favoriteButton.snp.leading).offset(
                -(Constants.contentSpacing - Constants.favoriteTouchOutset)
            )
            make.centerY.equalToSuperview()
            make.height.equalTo(Constants.sparklineSize.height)
            sparklineWidthConstraint = make.width.equalTo(Constants.sparklineSize.width).constraint
        }

        sparklineLoadingView.snp.makeConstraints { make in
            make.center.equalTo(sparklineView)
            make.size.equalTo(Constants.sparklinePlaceholderSize)
        }

        dividerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview()
            make.height.equalTo(UIConstants.separatorHeight)
        }
    }

    func setupValuesLayout(labelsView: UIView, valuesView: UIView) {
        valuesView.snp.makeConstraints { make in
            valuesTrailingConstraint = make.trailing.equalTo(sparklineView.snp.leading)
                .offset(-Constants.contentSpacing)
                .constraint
            make.centerY.equalToSuperview()
        }

        changeLabel.snp.makeConstraints { make in
            make.height.equalTo(Constants.changeHeight)
        }

        changeLoadingView.snp.makeConstraints { make in
            make.trailing.equalTo(changeLabel)
            make.centerY.equalTo(changeLabel)
            make.size.equalTo(Constants.changePlaceholderSize)
        }

        labelsView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Constants.contentSpacing)
            make.trailing.lessThanOrEqualTo(valuesView.snp.leading).offset(-Constants.contentSpacing)
            make.centerY.equalToSuperview()
        }

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valuesView.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}

final class SubtensorSubnetSkeletonCell: UITableViewCell, SkeletonableView {
    var skeletonView: SkrullableView?
    var skeletonSuperview: UIView { contentView }
    var skeletonSpaceSize: CGSize { contentView.bounds.size }
    var hidingViews: [UIView] { [] }

    let favoriteView: UIImageView = .create { view in
        view.image = SubtensorSubnetCell.unfavoriteImage
        view.contentMode = .scaleAspectFit
    }

    let dividerView: UIView = .create { view in
        view.backgroundColor = R.color.colorDivider()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if skeletonView == nil {
            startLoadingIfNeeded()
        } else if skeletonView?.bounds.size != skeletonSpaceSize {
            updateLoadingState()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            skeletonView?.stopSkrulling()
        } else {
            skeletonView?.restartSkrulling()
        }
    }

    func createSkeletons(for size: CGSize) -> [Skeletonable] {
        guard size.width > 0 else {
            return []
        }

        typealias Metrics = SubtensorSubnetCell.Constants

        let centerY = size.height / 2
        let labelsLeading = Metrics.contentInset + Metrics.iconSize + Metrics.contentSpacing
        let sparklineLeading = size.width - Metrics.contentInset - Metrics.favoriteSize - Metrics.contentSpacing -
            Metrics.sparklineSize.width
        let valuesTrailing = sparklineLeading - Metrics.contentSpacing

        let shapes: [(CGPoint, CGSize)] = [
            (
                CGPoint(x: Metrics.contentInset, y: centerY - Metrics.iconSize / 2),
                CGSize(width: Metrics.iconSize, height: Metrics.iconSize)
            ),
            (CGPoint(x: labelsLeading, y: centerY - 12), Metrics.titlePlaceholderSize),
            (CGPoint(x: labelsLeading, y: centerY + 2), Metrics.subtitlePlaceholderSize),
            (
                CGPoint(x: valuesTrailing - Metrics.pricePlaceholderSize.width, y: centerY - 12),
                Metrics.pricePlaceholderSize
            ),
            (
                CGPoint(x: valuesTrailing - Metrics.changePlaceholderSize.width, y: centerY + 2),
                Metrics.changePlaceholderSize
            ),
            (
                CGPoint(x: sparklineLeading, y: centerY - Metrics.sparklinePlaceholderSize.height / 2),
                Metrics.sparklinePlaceholderSize
            )
        ]

        return shapes.map { offset, shapeSize in
            SingleSkeleton.createRow(
                on: self,
                containerView: contentView,
                spaceSize: size,
                offset: offset,
                size: shapeSize
            )
        }
    }

    private func setupLayout() {
        [favoriteView, dividerView].forEach(contentView.addSubview)

        favoriteView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(SubtensorSubnetCell.Constants.contentInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(SubtensorSubnetCell.Constants.favoriteSize)
        }

        dividerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview()
            make.height.equalTo(UIConstants.separatorHeight)
        }
    }
}

extension SubtensorSubnetCell {
    enum Constants {
        static let contentInset: CGFloat = 28
        static let iconSize: CGFloat = 32
        static let favoriteSize: CGFloat = 20
        static let favoriteTouchOutset: CGFloat = 8
        static let sparklineSize = CGSize(width: 40, height: 20)
        static let contentSpacing: CGFloat = 12
        static let labelsSpacing: CGFloat = 2
        static let changeHeight: CGFloat = 16
        static let titlePlaceholderSize = CGSize(width: 110, height: 12)
        static let subtitlePlaceholderSize = CGSize(width: 70, height: 10)
        static let pricePlaceholderSize = CGSize(width: 70, height: 12)
        static let changePlaceholderSize = CGSize(width: 50, height: 10)
        static let sparklinePlaceholderSize = CGSize(width: 40, height: 12)
    }
}
