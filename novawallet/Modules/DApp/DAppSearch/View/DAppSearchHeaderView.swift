import UIKit

final class DAppSearchHeaderView: UITableViewHeaderFooterView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .caption1
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        let backgroundView = UIView()
        backgroundView.backgroundColor = R.color.colorBlack()
        self.backgroundView = backgroundView

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
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview().inset(4.0)
        }
    }
}
