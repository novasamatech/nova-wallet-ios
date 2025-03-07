import UIKit

final class NotificationsManagementViewLayout: UIView {
    let footerView = NotificationsManagementTableFooterView()

    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = R.color.colorSecondaryScreenBackground()
        view.separatorStyle = .none
        view.rowHeight = 55
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        footerView.bounds = CGRect(
            origin: .zero,
            size: CGSize(width: bounds.width, height: 106)
        )
        tableView.contentInset = .init(
            top: 16,
            left: 0,
            bottom: 8,
            right: 0
        )
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        tableView.tableFooterView = footerView
    }
}
