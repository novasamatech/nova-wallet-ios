import UIKit
import SnapKit

final class SettingsViewLayout: UIView {
    let headerView = SettingsTableHeaderView()
    let footerView = SettingsTableFooterView()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = R.color.colorBlack()
        view.separatorColor = R.color.colorDarkGray()
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

        headerView.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: 127))
        footerView.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: 122))
        tableView.contentInset = .init(top: 0, left: 0, bottom: footerView.frame.height + 16, right: 0)
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        tableView.tableHeaderView = headerView
        tableView.tableFooterView = footerView
    }
}
