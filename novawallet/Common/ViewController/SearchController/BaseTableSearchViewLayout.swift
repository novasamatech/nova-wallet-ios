import UIKit
import SoraUI

class BaseTableSearchViewLayout: UIView {
    let searchView: CustomSearchView = {
        let view = CustomSearchView()
        view.searchBar.textField.autocorrectionType = .no
        view.searchBar.textField.autocapitalizationType = .none
        view.cancelButton.isHidden = true
        view.cancelButton.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 16)
        return view
    }()

    var searchField: UITextField { searchView.searchBar.textField }
    var cancelButton: RoundedButton { searchView.cancelButton }

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableView.automaticDimension
        return tableView
    }()

    let emptyStateContainer = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(Constants.searchBarHeight)
        }

        addSubview(emptyStateContainer)
        emptyStateContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalTo(safeAreaLayoutGuide)
            make.top.equalTo(searchView.snp.bottom)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchView.snp.bottom)
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.bottom.equalToSuperview()
        }
    }

    func setupStyle() {
        let color = R.color.colorSecondaryScreenBackground()!
        backgroundColor = color
        tableView.backgroundColor = color
        emptyStateContainer.backgroundColor = color
    }
}

extension BaseTableSearchViewLayout {
    enum Constants {
        static let searchBarHeight: CGFloat = 54
    }
}
