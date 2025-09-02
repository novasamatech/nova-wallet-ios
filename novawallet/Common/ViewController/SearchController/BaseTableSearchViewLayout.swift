import UIKit
import UIKit_iOS

class BaseTableSearchViewLayout: UIView {
    let searchView: CustomSearchView = {
        let view = CustomSearchView()
        view.searchBar.textField.autocorrectionType = .no
        view.searchBar.textField.autocapitalizationType = .none
        view.cancelButton.isHidden = true
        view.cancelButton.contentInsets = Constants.cancelButtonInsets
        return view
    }()

    var searchField: UITextField { searchView.searchBar.textField }

    var cancelButton: RoundedButton { searchView.cancelButton }

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.contentInset = Constants.tableViewContentInsets
        tableView.separatorStyle = .none
        return tableView
    }()

    let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

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
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.edges.equalToSuperview()
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.bottom.equalToSuperview()
        }

        addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(Constants.searchBarHeight)
        }
    }

    func setupStyle() {
        let color = R.color.colorSecondaryScreenBackground()
        backgroundColor = color
        tableView.backgroundColor = color
        searchView.blurBackgroundView.borderType = .none
    }
}

extension BaseTableSearchViewLayout {
    enum Constants {
        static let searchBarHeight: CGFloat = 54
        static let tableViewContentInsets = UIEdgeInsets(
            top: Constants.searchBarHeight,
            left: 0,
            bottom: 16,
            right: 0
        )
        static let cancelButtonInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 16)
    }
}
