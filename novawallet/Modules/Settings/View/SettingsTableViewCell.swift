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

    let roundView: RoundedView = {
        let view = RoundedView()
        view.fillColor = R.color.color0x1D1D20()!
        view.cornerRadius = 10
        view.shadowOpacity = 0.0
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        selectionStyle = .none
        separatorInset = .init(top: 0, left: 32, bottom: 0, right: 32)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)

        roundView.fillColor = highlighted ? R.color.colorAccentSelected()! : R.color.color0x1D1D20()!
    }

    private func setupLayout() {
        let arrowIcon = UIImageView(image: R.image.iconChevronRight())
        let content = UIView.hStack(alignment: .center, spacing: 12, [
            iconImageView, titleLabel, UIView(), subtitleLabel, arrowIcon
        ])
        iconImageView.snp.makeConstraints { $0.size.equalTo(24) }
        arrowIcon.snp.makeConstraints { $0.size.equalTo(16) }

        roundView.addSubview(content)
        content.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.top.equalToSuperview().inset(12)
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
