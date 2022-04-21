import UIKit

final class DAppSearchQueryTableViewCell: UITableViewCell {
    let iconImageView: DAppIconView = {
        let view = DAppIconView()
        view.contentInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
        view.backgroundView.cornerRadius = 12.0
        view.backgroundView.strokeWidth = 0.5
        view.backgroundView.strokeColor = R.color.colorWhite16()!
        view.backgroundView.highlightedStrokeColor = R.color.colorWhite16()!
        view.backgroundView.fillColor = R.color.colorWhite8()!
        view.backgroundView.highlightedFillColor = R.color.colorWhite8()!
        view.imageView.image = R.image.iconDefaultDapp()!
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .regularSubheadline
        return label
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

    func bind(title: String) {
        titleLabel.text = title
    }

    private func setupLayout() {
        contentView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16.0)
            make.centerY.equalToSuperview()
            make.size.equalTo(48.0)
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(iconImageView.snp.trailing).offset(12.0)
        }
    }
}
