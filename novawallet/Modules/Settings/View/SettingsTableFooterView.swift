import UIKit

final class SettingsTableFooterView: UITableViewHeaderFooterView {
    let appNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .p2Paragraph
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        backgroundView = UIView()
        backgroundView?.backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let logoIcon = UIImageView(image: R.image.iconStarGray32())
        let content = UIView.vStack(alignment: .center, spacing: 8, [logoIcon, appNameLabel])
        logoIcon.snp.makeConstraints { $0.size.equalTo(32) }

        contentView.addSubview(content)
        content.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(32)
            make.leading.trailing.equalToSuperview()
        }
    }
}
