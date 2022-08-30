import Foundation
import UIKit

final class AccountManagementViewLayout: UIView, TableHeaderLayoutUpdatable {
    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.separatorStyle = .none
        return view
    }()

    let headerView = AccountManagementHeaderView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateHeaderLayout() {
        updateTableHeaderLayout(headerView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        updateHeaderLayout()
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.bottom.equalToSuperview()
        }

        tableView.tableHeaderView = headerView
    }
}
