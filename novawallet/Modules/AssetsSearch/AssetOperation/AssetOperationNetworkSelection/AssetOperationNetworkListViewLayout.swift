import UIKit

final class AssetOperationNetworkListViewLayout: UIView {
    let tableView: UITableView = .create { view in
        view.backgroundColor = .clear
        view.separatorStyle = .none
    }

    let headerView: MultiValueView = .createTableHeaderView()

    var headerLabel: UILabel {
        headerView.valueTop
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

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tableView.tableHeaderView = headerView
    }
}
