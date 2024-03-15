import UIKit

final class SettingsSectionFooterView: UITableViewHeaderFooterView {
    let titleLabel: UILabel = .create {
        $0.apply(style: .caption1Secondary)
        $0.numberOfLines = 0
    }

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

    func setupLayout() {
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(12)
            make.bottom.equalToSuperview()
        }
    }
}
