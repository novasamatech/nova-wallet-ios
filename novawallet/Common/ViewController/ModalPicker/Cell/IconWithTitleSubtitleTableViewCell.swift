import UIKit

class IconWithTitleSubtitleTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    typealias Model = IconWithTitleSubtitleViewModel

    private(set) var titleLabel = UILabel()
    private(set) var subtitleLabel = UILabel()
    private(set) var iconImageView = UIImageView()

    var checkmarked: Bool = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorAccentSelected()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(model: Model) {
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
        iconImageView.image = model.icon
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
            make.top.equalToSuperview().inset(7.0)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12.0)
            make.trailing.equalToSuperview().inset(8.0)
        }

        contentView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(7.0)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12.0)
            make.trailing.equalToSuperview().inset(8.0)
        }
    }
}
