import UIKit
import SoraUI

final class ValidatorSearchViewLayout: UIView {
    let searchView: CustomSearchView = {
        let view = CustomSearchView()
        view.searchBar.textField.autocorrectionType = .no
        view.searchBar.textField.autocapitalizationType = .none
        view.cancelButton.isHidden = true
        view.cancelButton.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 16)
        return view
    }()

    var searchField: UITextField { searchView.searchBar.textField }

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = R.color.colorSecondaryScreenBackground()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
        return tableView
    }()

    let emptyStateContainer: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorSecondaryScreenBackground()
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(54)
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
}
