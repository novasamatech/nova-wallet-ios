import UIKit
import SnapKit

final class SettingsViewLayout: UIView {
    let headerView = SettingsTableHeaderView()
    let footerView = SettingsTableFooterView()

    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = R.color.colorSecondaryScreenBackground()
        view.separatorColor = R.color.colorDivider()
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

        headerView.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: 118))
        footerView.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: 92))
        tableView.contentInset = .init(top: 0, left: 0, bottom: footerView.frame.height + 6, right: 0)
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
