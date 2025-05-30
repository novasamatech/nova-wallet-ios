import UIKit
import UIKit_iOS
import Foundation_iOS

class YourValidatorListDescSectionView: UITableViewHeaderFooterView {
    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextSecondary()!
        label.numberOfLines = 0
        return label
    }()

    let mainStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0)
        return stackView
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
        contentView.addSubview(mainStackView)
        mainStackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        mainStackView.addArrangedSubview(descriptionLabel)
    }

    func bind(description: String) {
        descriptionLabel.text = description
    }
}
