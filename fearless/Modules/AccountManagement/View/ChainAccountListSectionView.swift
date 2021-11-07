import UIKit
import SoraUI
import SoraFoundation

class ChainAccountListSectionView: UITableViewHeaderFooterView {
    // FIXME: Remove bordered view
    let borderView: BorderedContainerView = {
        let view = UIFactory.default.createBorderedContainerView()
        view.borderType = .none
        return view
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()!
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
        contentView.addSubview(borderView)
        borderView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        borderView.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalToSuperview().inset(16.0)
        }
    }

    func bind(description: String) {
        descriptionLabel.text = description
    }
}
