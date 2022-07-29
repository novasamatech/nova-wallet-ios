import UIKit
import SoraUI
import SoraFoundation

class ChainAccountListSectionView: UITableViewHeaderFooterView {
    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldCaps2
        label.textColor = R.color.colorTransparentText()
        label.numberOfLines = 0
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        backgroundView = UIView()
        backgroundView?.backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        contentView.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview().inset(16.0)
            make.top.equalToSuperview().inset(16.0)
        }
    }

    func bind(description: String) {
        descriptionLabel.text = description
    }
}
