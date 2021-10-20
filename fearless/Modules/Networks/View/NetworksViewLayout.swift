import UIKit

final class NetworksViewLayout: UIView {
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.tableFooterView = UIView()
        return tableView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.bottom.trailing.equalToSuperview()
        }
    }
}
