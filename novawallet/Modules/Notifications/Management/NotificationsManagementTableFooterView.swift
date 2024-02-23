import UIKit

final class NotificationsManagementTableFooterView: UITableViewHeaderFooterView {
    let titleLabel: UILabel = .create {
        $0.apply(style: .footnoteSecondary)
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

    private func setupLayout() {
        let logoIcon = UIImageView(image: R.image.iconWeb3AlertsLogo()!)
        let content = UIView.vStack(alignment: .center, spacing: 16, [
            titleLabel,
            logoIcon
        ])
        logoIcon.snp.makeConstraints { $0.height.equalTo(40) }

        contentView.addSubview(content)
        content.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16)
            make.bottom.leading.trailing.equalToSuperview()
        }
    }
}
