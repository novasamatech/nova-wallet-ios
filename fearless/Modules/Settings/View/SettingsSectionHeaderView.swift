import UIKit

final class SettingsSectionHeaderView: UITableViewHeaderFooterView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .p3Paragraph
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
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(32)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(12)
        }
    }
}
