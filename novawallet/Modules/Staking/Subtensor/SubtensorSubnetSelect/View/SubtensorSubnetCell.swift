import SubstrateSdk
import UIKit
import UIKit_iOS

final class SubtensorSubnetCell: UITableViewCell {
    let iconView: PolkadotIconView = .create { view in
        view.backgroundColor = .clear
        view.fillColor = .clear
    }

    let rootSymbolLabel: UILabel = .create { label in
        label.font = .semiBoldBody
        label.textColor = R.color.colorTextPrimary()
        label.textAlignment = .center
        label.text = "T"
        label.backgroundColor = R.color.colorContainerBackground()
        label.layer.cornerRadius = Constants.iconSize / 2
        label.clipsToBounds = true
    }

    let titleLabel: UILabel = .create { label in
        label.font = .semiBoldSubheadline
        label.textColor = R.color.colorTextPrimary()
        label.lineBreakMode = .byTruncatingTail
    }

    let subtitleLabel: UILabel = .create { label in
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        label.lineBreakMode = .byTruncatingTail
    }

    let priceLabel: UILabel = .create { label in
        label.font = .semiBoldFootnote
        label.textColor = R.color.colorTextPrimary()
        label.textAlignment = .right
    }

    let changeLabel: UILabel = .create { label in
        label.font = .caption1
        label.textAlignment = .right
    }

    let favoriteButton: UIButton = .create { button in
        button.contentMode = .scaleAspectFit
    }

    var favoriteAction: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellBackgroundPressed()
        favoriteButton.addTarget(self, action: #selector(didTapFavorite), for: .touchUpInside)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        favoriteAction = nil
    }

    func bind(viewModel: SubtensorSubnetSelectViewModel, locale: Locale) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let isRoot = viewModel.target.isRoot

        iconView.isHidden = isRoot || viewModel.icon == nil
        rootSymbolLabel.isHidden = !iconView.isHidden
        if let icon = viewModel.icon { iconView.bind(icon: icon) }

        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        subtitleLabel.isHidden = !isRoot

        priceLabel.text = isRoot ? nil : viewModel.price.map { "\($0) TAO" }
        changeLabel.text = viewModel.weeklyChangeText.map { "\($0) · 7D" }
        changeLabel.textColor = (viewModel.weeklyChange ?? 0) < 0
            ? R.color.colorTextNegative()
            : R.color.colorTextPositive()

        favoriteButton.isHidden = isRoot
        favoriteButton.setImage(
            viewModel.isFavorite ? R.image.iconFavToolbarSel() : R.image.iconUnfavorite(),
            for: .normal
        )
        favoriteButton.accessibilityLabel = strings.stakingSubtensorUiPickerFavoriteAccessibility()
        favoriteButton.accessibilityValue = viewModel.isFavorite ? strings.commonOn() : strings.commonOff()
    }

    func bindLoadingRoot(locale: Locale) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        iconView.isHidden = true
        rootSymbolLabel.isHidden = false
        titleLabel.text = strings.stakingSubtensorUiRootStaking()
        subtitleLabel.text = strings.stakingSubtensorUiPickerRootSubtitle()
        subtitleLabel.isHidden = false
        priceLabel.text = nil
        changeLabel.text = nil
        favoriteButton.isHidden = true
    }

    @objc private func didTapFavorite() {
        favoriteAction?()
    }
}

final class SubtensorSubnetSkeletonCell: UITableViewCell, SkeletonableView {
    var skeletonView: SkrullableView?
    var skeletonSuperview: UIView { contentView }
    var skeletonSpaceSize: CGSize { contentView.bounds.size }
    var hidingViews: [UIView] {
        [iconPlaceholder, titlePlaceholder, subtitlePlaceholder, pricePlaceholder, changePlaceholder]
    }

    private let iconPlaceholder = UIView()
    private let titlePlaceholder = UIView()
    private let subtitlePlaceholder = UIView()
    private let pricePlaceholder = UIView()
    private let changePlaceholder = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        [iconPlaceholder, titlePlaceholder, subtitlePlaceholder, pricePlaceholder, changePlaceholder]
            .forEach { placeholder in
                placeholder.backgroundColor = R.color.colorBlockBackground()
                placeholder.layer.cornerRadius = 6
                contentView.addSubview(placeholder)
            }

        iconPlaceholder.layer.cornerRadius = 16

        iconPlaceholder.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(32)
        }

        titlePlaceholder.snp.makeConstraints { make in
            make.leading.equalTo(iconPlaceholder.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(17)
            make.width.equalTo(110)
            make.height.equalTo(12)
        }

        subtitlePlaceholder.snp.makeConstraints { make in
            make.leading.equalTo(titlePlaceholder)
            make.top.equalTo(titlePlaceholder.snp.bottom).offset(4)
            make.width.equalTo(70)
            make.height.equalTo(10)
        }

        pricePlaceholder.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(56)
            make.top.equalTo(titlePlaceholder)
            make.width.equalTo(70)
            make.height.equalTo(12)
        }

        changePlaceholder.snp.makeConstraints { make in
            make.trailing.equalTo(pricePlaceholder)
            make.top.equalTo(subtitlePlaceholder)
            make.width.equalTo(50)
            make.height.equalTo(10)
        }
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
        guard size.width > 0 else { return [] }
        let shapes: [(CGPoint, CGSize)] = [
            (CGPoint(x: Constants.horizontalInset, y: 14), CGSize(width: 32, height: 32)),
            (CGPoint(x: Constants.horizontalInset + 44, y: 17), CGSize(width: 110, height: 12)),
            (CGPoint(x: Constants.horizontalInset + 44, y: 33), CGSize(width: 70, height: 10)),
            (CGPoint(x: size.width - 126, y: 17), CGSize(width: 70, height: 12)),
            (CGPoint(x: size.width - 106, y: 33), CGSize(width: 50, height: 10))
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

    private enum Constants {
        static let horizontalInset: CGFloat = 28
    }
}

private extension SubtensorSubnetCell {
    func setupLayout() {
        let labels = UIStackView.vStack(alignment: .leading, spacing: 2, [titleLabel, subtitleLabel])
        let values = UIStackView.vStack(alignment: .trailing, spacing: 2, [priceLabel, changeLabel])

        [iconView, rootSymbolLabel, labels, values, favoriteButton].forEach(contentView.addSubview)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        rootSymbolLabel.snp.makeConstraints { make in
            make.edges.equalTo(iconView)
        }

        labels.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Constants.contentSpacing)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(values.snp.leading).offset(-Constants.contentSpacing)
        }

        favoriteButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.favoriteSize)
        }

        values.snp.makeConstraints { make in
            make.trailing.equalTo(favoriteButton.snp.leading).offset(-Constants.contentSpacing)
            make.centerY.equalToSuperview()
        }
    }

    enum Constants {
        static let horizontalInset: CGFloat = 16
        static let iconSize: CGFloat = 32
        static let favoriteSize: CGFloat = 24
        static let contentSpacing: CGFloat = 12
    }
}
