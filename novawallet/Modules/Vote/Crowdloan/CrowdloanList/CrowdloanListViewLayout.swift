import UIKit
import SnapKit

final class CrowdloanListViewLayout: UIView {
    private let backgroundView = MultigradientView.background

    let headerView = CrowdloanTableHeaderView()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.separatorColor = R.color.colorDarkGray()
        view.refreshControl = UIRefreshControl()
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

        let height = headerView.systemLayoutSizeFitting(
            CGSize(width: bounds.size.width, height: UIView.layoutFittingExpandedSize.height)
        ).height

        var headerFrame = headerView.frame

        // Comparison necessary to avoid infinite loop
        if height != headerFrame.size.height {
            headerFrame.size.height = height
            headerView.frame = headerFrame
            tableView.tableHeaderView = headerView
        }
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
