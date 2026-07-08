import UIKit
import UIKit_iOS

protocol ManageTokenSectionHeaderCellDelegate: AnyObject {
    func sectionHeaderCellDidTap(_ cell: ManageTokenSectionHeaderCell)
}

final class ManageTokenSectionHeaderCell: UITableViewCell {
    private enum Constants {
        static let iconSize = CGSize(width: 32, height: 32)
        static let chevronSize = CGSize(width: 24, height: 24)
    }

    weak var delegate: ManageTokenSectionHeaderCellDelegate?

    let iconView: AssetIconView = .create {
        $0.backgroundView.apply(style: .tokenContainer)
        $0.backgroundView.cornerRadius = Constants.iconSize.height / 2.0
        $0.contentInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
    }

    let titleLabel: UILabel = .create { label in
        label.textColor = R.color.colorTextPrimary()
        label.font = .semiBoldBody
    }

    let countLabel: UILabel = .create { label in
        label.textColor = R.color.colorTextSecondary()
        label.font = .regularFootnote
    }

    let chevronImageView: UIImageView = .create { view in
        view.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)
        view.contentMode = .center
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = R.color.colorSecondaryScreenBackground()!

        setupLayout()
        setupHandlers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        chevronImageView.transform = .identity
        iconView.bind(viewModel: nil, size: Constants.iconSize)
    }

    func bind(section: ManageTokenSection) {
        titleLabel.text = section.title

        let countText = "\(section.enabledCount)/\(section.items.count)"
        countLabel.text = countText

        let iconSize = CGSize(
            width: Constants.iconSize.width - 8,
            height: Constants.iconSize.height - 8
        )

        iconView.bind(viewModel: section.icon, size: iconSize)

        let angle: CGFloat = section.isExpanded ? .pi / 2 : 0
        chevronImageView.transform = CGAffineTransform(rotationAngle: angle)
    }

    private func setupHandlers() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(actionTap))
        contentView.addGestureRecognizer(tapGesture)
    }

    private func setupLayout() {
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        contentView.addSubview(chevronImageView)
        chevronImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.chevronSize)
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.top.equalToSuperview().inset(8)
        }

        contentView.addSubview(countLabel)
        countLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-8)
        }

        titleLabel.snp.makeConstraints { make in
            make.trailing.lessThanOrEqualTo(chevronImageView.snp.leading).offset(-8)
        }
    }

    @objc private func actionTap() {
        delegate?.sectionHeaderCellDidTap(self)
    }
}
