import Foundation
import UIKit

final class VoteViewLayout: UIView, TableHeaderLayoutUpdatable {
    private let backgroundView = UIImageView.background

    let headerView = VoteTableHeaderView()

    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = .clear
        view.separatorColor = R.color.colorDivider()
        view.tableFooterView = UIView()
        view.separatorStyle = .none
        view.contentInset = .init(top: 0, left: 0, bottom: 16, right: 0)
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        updateTableHeaderLayout(headerView)
    }

    private func setup() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.bottom.trailing.equalToSuperview()
        }

        tableView.tableHeaderView = headerView
    }
}
