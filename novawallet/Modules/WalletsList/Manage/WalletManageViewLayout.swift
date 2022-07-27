import UIKit

class WalletManageViewLayout: WalletsListViewLayout {
    let addWalletButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.changesContentOpacityWhenHighlighted = true
        return button
    }()

    let editButton: UIBarButtonItem = {
        let button = UIBarButtonItem()
        button.style = .plain

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorNovaBlue()!,
            .font: UIFont.regularBody
        ]

        button.setTitleTextAttributes(attributes, for: .normal)
        button.setTitleTextAttributes(attributes, for: .highlighted)

        return button
    }()

    override func layoutSubviews() {
        super.layoutSubviews()

        let bottomInset = bounds.maxY - addWalletButton.frame.minY + 16.0
        tableView.contentInset = .init(top: 0, left: 0, bottom: bottomInset, right: 0)
    }

    override func setupLayout() {
        super.setupLayout()

        addSubview(addWalletButton)
        addWalletButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }
    }
}
