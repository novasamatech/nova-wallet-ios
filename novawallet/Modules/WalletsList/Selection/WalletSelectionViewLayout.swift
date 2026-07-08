import UIKit

class WalletSelectionViewLayout: WalletsListViewLayout {
    let settingsButton: UIBarButtonItem = {
        let button = UIBarButtonItem()
        button.image = R.image.iconSettings()
        return button
    }()

    let searchTextField: UITextField = {
        let field = UITextField()
        field.placeholder = R.string.localizable.commonSearchWalletsPlaceholder(preferredLanguages: [])
        field.borderStyle = .roundedRect
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .search
        return field
    }()

    override func setupLayout() {
        addSubview(searchTextField)
        searchTextField.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(36)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchTextField.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
