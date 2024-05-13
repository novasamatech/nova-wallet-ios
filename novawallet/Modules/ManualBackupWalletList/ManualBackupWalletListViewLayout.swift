import UIKit

final class ManualBackupWalletListViewLayout: WalletsListViewLayout {
    override var tableView: UITableView {
        get { groupedTableView }
        set { groupedTableView = newValue }
    }

    private var groupedTableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.separatorStyle = .none
        view.backgroundColor = .clear
        return view
    }()
}
