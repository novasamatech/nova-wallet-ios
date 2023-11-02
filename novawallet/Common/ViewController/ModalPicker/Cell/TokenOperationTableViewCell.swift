import UIKit

final class TokenOperationTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    struct Model {
        let content: IconWithTitleSubtitleViewModel
        let isActive: Bool
    }

    private(set) var titleLabel = UILabel()
    private(set) var subtitleLabel = UILabel()
    private(set) var iconImageView = UIImageView()
    let arrowIcon = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)

    var checkmarked: Bool = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupStyle()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(model: Model) {
        titleLabel.text = model.content.title
        subtitleLabel.text = model.content.subtitle
        iconImageView.image = model.content.icon

        if model.isActive {
            titleLabel.textColor = R.color.colorTextPrimary()
            subtitleLabel.textColor = R.color.colorTextSecondary()
            iconImageView.tintColor = R.color.colorIconPrimary()
            accessoryView = UIImageView(image: arrowIcon)
            selectionStyle = .default
        } else {
            titleLabel.textColor = R.color.colorButtonTextInactive()
            subtitleLabel.textColor = R.color.colorButtonTextInactive()
            iconImageView.tintColor = R.color.colorIconInactive()
            accessoryView = nil
            selectionStyle = .none
        }
    }

    private func setupStyle() {
        backgroundColor = .clear

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellBackgroundPressed()

        separatorInset = UIEdgeInsets(
            top: 0,
            left: UIConstants.horizontalInset,
            bottom: 0,
            right: UIConstants.horizontalInset
        )

        titleLabel.apply(style: .regularSubhedlinePrimary)
        subtitleLabel.apply(style: .footnoteSecondary)
    }

    private func setupLayout() {
        contentView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        iconImageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        iconImageView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(7)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(8)
        }

        contentView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(7)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(8)
        }
    }
}
