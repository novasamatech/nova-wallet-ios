import SubstrateSdk
import UIKit
import UIKit_iOS

final class SubtensorValidatorSelectCell: UITableViewCell {
    let radioView = UIImageView()

    let iconView: PolkadotIconView = .create { view in
        view.backgroundColor = .clear
        view.fillColor = .clear
    }

    let titleLabel: UILabel = .create { label in
        label.font = .regularSubheadline
        label.textColor = R.color.colorTextPrimary()
    }

    let recommendedView: BorderedLabelView = .create { view in
        view.titleLabel.font = .semiBoldCaps2
        view.titleLabel.textColor = R.color.colorIndividualChipText()
        view.backgroundView.fillColor = R.color.colorIndividualChipBackground()!
        view.backgroundView.highlightedFillColor = R.color.colorIndividualChipBackground()!
        view.backgroundView.cornerRadius = 6
        view.contentInsets = UIEdgeInsets(top: 1, left: 6, bottom: 1, right: 6)
        view.isHidden = true
    }

    let titleStackView: UIStackView = .create { view in
        view.axis = .horizontal
        view.alignment = .center
        view.spacing = 8
    }

    let subtitleLabel: UILabel = .create { label in
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
    }

    let trailingLabel: UILabel = .create { label in
        label.font = .regularSubheadline
        label.textAlignment = .right
    }

    let infoButton: UIButton = .create { button in
        button.setImage(R.image.iconInfoFilled(), for: .normal)
    }

    let divider: UIView = .create { view in
        view.backgroundColor = R.color.colorDivider()
    }

    var infoAction: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellBackgroundPressed()

        infoButton.addTarget(self, action: #selector(actionInfo), for: .touchUpInside)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        infoAction = nil
    }

    func bind(_ model: SubtensorValidatorRowViewModel, icon: DrawableIcon?, recommendedTitle: String) {
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle

        recommendedView.titleLabel.text = recommendedTitle
        recommendedView.isHidden = !model.isRecommended

        switch model.trailing {
        case let .rate(text):
            trailingLabel.text = text
            trailingLabel.textColor = R.color.colorTextPositive()
        case let .inactive(text):
            trailingLabel.text = text
            trailingLabel.textColor = R.color.colorTextSecondary()
        case .none:
            trailingLabel.text = nil
        }

        radioView.image = model.isSelected
            ? R.image.iconRadioButtonSelected()
            : R.image.iconRadioButtonUnselected()

        radioView.alpha = model.isSelectable ? 1 : 0.5
        selectionStyle = model.isSelectable ? .default : .none

        if let icon {
            iconView.bind(icon: icon)
        }
    }

    @objc private func actionInfo() {
        infoAction?()
    }

    private func setupLayout() {
        titleStackView.addArrangedSubview(titleLabel)
        titleStackView.addArrangedSubview(recommendedView)

        [radioView, iconView, titleStackView, subtitleLabel, trailingLabel, infoButton, divider]
            .forEach(contentView.addSubview)

        radioView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        iconView.snp.makeConstraints { make in
            make.leading.equalTo(radioView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        titleStackView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(10)
            make.trailing.lessThanOrEqualTo(trailingLabel.snp.leading).offset(-8)
        }

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        recommendedView.setContentCompressionResistancePriority(.required, for: .horizontal)

        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleStackView)
            make.top.equalTo(titleStackView.snp.bottom).offset(2)
            make.trailing.lessThanOrEqualTo(trailingLabel.snp.leading).offset(-8)
        }

        infoButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(8)
            make.centerY.equalToSuperview()
            make.size.equalTo(32)
        }

        trailingLabel.snp.makeConstraints { make in
            make.trailing.equalTo(infoButton.snp.leading).offset(-4)
            make.centerY.equalToSuperview()
        }

        trailingLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        divider.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }
}

final class SubtensorValidatorSkeletonCell: UITableViewCell, SkeletonableView {
    var skeletonView: SkrullableView?
    var skeletonSuperview: UIView { contentView }
    var hidingViews: [UIView] { [] }
    var skeletonSpaceSize: CGSize { contentView.bounds.size }

    private let radioView = UIImageView(image: R.image.iconRadioButtonUnselected())
    private let infoView = UIImageView(image: R.image.iconInfoFilled())

    private let divider: UIView = .create { view in
        view.backgroundColor = R.color.colorDivider()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none

        [radioView, infoView, divider].forEach(contentView.addSubview)

        radioView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        infoView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }

        divider.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
            make.height.equalTo(0.5)
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

        [radioView, infoView, divider].forEach(contentView.bringSubviewToFront)
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

        let shapes: [(CGPoint, CGSize)] = [
            (CGPoint(x: 52, y: 17), CGSize(width: 24, height: 24)),
            (CGPoint(x: 88, y: 14), CGSize(width: 120, height: 12)),
            (CGPoint(x: 88, y: 31), CGSize(width: min(160, size.width - 168), height: 10)),
            (CGPoint(x: size.width - 92, y: 23), CGSize(width: 48, height: 12))
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
}
