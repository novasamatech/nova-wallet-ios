import UIKit

final class TokensManageSectionHeaderView: UITableViewHeaderFooterView {
    let titleLabel = UILabel()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        backgroundView = UIView()
        backgroundView?.backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(title: String) {
        titleLabel.apply(style: .semiboldCaps1Secondary)
        titleLabel.text = title.uppercased()

        updateCenterOffset(Constants.titleCenterOffset)
    }

    func bind(caption: String) {
        titleLabel.apply(style: .regularSubhedlineSecondary)
        titleLabel.text = caption

        updateCenterOffset(Constants.captionCenterOffset)
    }
}

// MARK: Private

private extension TokensManageSectionHeaderView {
    func setupLayout() {
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.centerY.equalToSuperview().offset(Constants.titleCenterOffset)
        }
    }

    func updateCenterOffset(_ offset: CGFloat) {
        titleLabel.snp.updateConstraints { make in
            make.centerY.equalToSuperview().offset(offset)
        }
    }
}

// MARK: Constants

extension TokensManageSectionHeaderView {
    enum Constants {
        static let titleHeight: CGFloat = 32
        static let captionHeight: CGFloat = 44
        static let horizontalInset: CGFloat = 20
        static let titleTopInset: CGFloat = 8
        static let titleBottomInset: CGFloat = 4
        static let titleCenterOffset: CGFloat = (titleTopInset - titleBottomInset) / 2
        static let captionCenterOffset: CGFloat = 0
    }
}
