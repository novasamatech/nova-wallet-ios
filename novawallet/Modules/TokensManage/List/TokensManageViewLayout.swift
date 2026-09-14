import UIKit

final class TokensManageViewLayout: UIView {
    let searchView = TopCustomSearchView()

    var searchBar: CustomSearchBar {
        searchView.searchBar
    }

    var searchTextField: UITextField {
        searchBar.textField
    }

    let addTokenButton: UIBarButtonItem = TokensManageViewLayout.createAddTokenButtonItem()

    let autoAddView = TokensManageAutoAddView()

    let contentView: UIView = .create {
        $0.backgroundColor = .clear
    }

    let tableView: UITableView = .create {
        $0.backgroundColor = .clear
        $0.separatorStyle = .none
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension TokensManageViewLayout {
    static func createAddTokenButtonItem() -> UIBarButtonItem {
        let button = UIBarButtonItem(
            image: R.image.iconSmallAdd()?.withRenderingMode(.alwaysTemplate),
            style: .plain,
            target: nil,
            action: nil
        )

        button.tintColor = R.color.colorButtonTextAccent()

        return button
    }

    func setupLayout() {
        addSubview(contentView)
        addSubview(searchView)
        addSubview(autoAddView)

        searchView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(Constants.preferredBarHeight)
        }

        autoAddView.snp.makeConstraints { make in
            make.top.equalTo(searchView.snp.bottom).offset(Constants.autoAddTopSpacing)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(TokensManageAutoAddView.Constants.height)
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(autoAddView.snp.bottom).offset(Constants.tableTopSpacing)
            make.leading.trailing.bottom.equalToSuperview()
        }

        contentView.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

// MARK: Constants

private extension TokensManageViewLayout {
    enum Constants {
        static let preferredBarHeight: CGFloat = 64.0
        static let autoAddTopSpacing: CGFloat = 12.0
        static let tableTopSpacing: CGFloat = 8.0
    }
}
