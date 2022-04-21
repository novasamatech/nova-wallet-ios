import UIKit

final class DAppSearchDAppTableViewCell: UITableViewCell {
    private enum Constants {
        static let iconInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
        static let iconSize = CGSize(width: 36.0, height: 36.0)

        static var preferredIconViewSize: CGSize {
            CGSize(
                width: iconInsets.left + iconSize.width + iconInsets.right,
                height: iconInsets.top + iconSize.height + iconInsets.bottom
            )
        }
    }

    let iconImageView: DAppIconView = {
        let view = DAppIconView()
        view.contentInsets = Constants.iconInsets
        view.backgroundView.cornerRadius = 12.0
        view.backgroundView.strokeWidth = 0.5
        view.backgroundView.strokeColor = R.color.colorWhite16()!
        view.backgroundView.highlightedStrokeColor = R.color.colorWhite16()!
        view.backgroundView.fillColor = R.color.colorWhite8()!
        view.backgroundView.highlightedFillColor = R.color.colorWhite8()!
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .regularSubheadline
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .caption1
        return label
    }()

    let accessoryImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        let selectedView = UIView()
        selectedView.backgroundColor = R.color.colorAccentSelected()
        selectedBackgroundView = selectedView

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: DAppViewModel) {
        iconImageView.bind(viewModel: viewModel.icon, size: Constants.iconSize)

        titleLabel.text = viewModel.name
        subtitleLabel.text = viewModel.details

        if viewModel.isFavorite {
            accessoryImageView.image = R.image.iconFavButtonSel()!
        } else {
            accessoryImageView.image = nil
        }
    }

    private func setupLayout() {
        contentView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.preferredIconViewSize)
        }

        contentView.addSubview(accessoryImageView)
        accessoryImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16.0)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.top).offset(4.0)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12.0)
            make.trailing.lessThanOrEqualTo(accessoryImageView.snp.leading).offset(-4.0)
        }

        contentView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4.0)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12.0)
            make.trailing.lessThanOrEqualTo(accessoryImageView.snp.leading).offset(-4.0)
        }
    }
}
