import UIKit
import SoraUI
import SoraFoundation

class ChainAccountListSectionView: UITableViewHeaderFooterView {
    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldCaps2
        label.textColor = R.color.colorTextSecondary()
        label.numberOfLines = 0
        return label
    }()

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

    func setupLayout() {
        contentView.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.bottom.equalToSuperview().inset(8.0)
        }
    }

    func bind(description: String) {
        descriptionLabel.text = description
    }
}
