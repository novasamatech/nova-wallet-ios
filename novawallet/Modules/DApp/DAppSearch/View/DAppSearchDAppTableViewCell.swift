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
        view.backgroundView.apply(style: .roundedContainer(radius: 12))
        return view
    }()

    let favoriteImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
        view.image = R.image.iconFavButtonSel()?.tinted(
            with: R.color.colorIconMiniFavorite()!
        )
    }

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .regularSubheadline
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = .caption1
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        let selectedView = UIView()
        selectedView.backgroundColor = R.color.colorCellBackgroundPressed()
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
            favoriteImageView.isHidden = false
        } else {
            favoriteImageView.isHidden = true
        }
    }

    private func setupLayout() {
        contentView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.preferredIconViewSize)
        }

        contentView.addSubview(favoriteImageView)
        favoriteImageView.snp.makeConstraints { make in
            make.size.equalTo(12.0)
            make.top.equalTo(iconImageView.snp.top).inset(-2)
            make.trailing.equalTo(iconImageView.snp.trailing).inset(-4.0)
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.top).offset(4.0)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12.0)
            make.trailing.lessThanOrEqualToSuperview().offset(-4.0)
        }

        contentView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4.0)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12.0)
            make.trailing.lessThanOrEqualToSuperview().offset(-4.0)
        }
    }
}
