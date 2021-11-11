import UIKit
import SoraUI

final class SettingsTableViewCell: UITableViewCell {
    private let iconImageView = UIImageView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView!.backgroundColor = R.color.colorAccent()!.withAlphaComponent(0.3)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let content = UIView.hStack(alignment: .center, spacing: 12, [
            iconImageView, titleLabel, UIView(), subtitleLabel
        ])
        iconImageView.snp.makeConstraints { $0.size.equalTo(24) }

        let roundView = UIView()
        roundView.backgroundColor = R.color.colorDarkGray()
        roundView.addSubview(content)
        content.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        contentView.addSubview(roundView)
        roundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.bottom.equalToSuperview()
        }
    }

    func bind(viewModel: SettingsCellViewModel) {
        iconImageView.image = viewModel.icon
        titleLabel.text = viewModel.title

        subtitleLabel.text = viewModel.accessoryTitle
    }
}
