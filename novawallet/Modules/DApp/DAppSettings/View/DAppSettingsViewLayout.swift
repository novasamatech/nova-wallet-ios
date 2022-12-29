import UIKit
import SnapKit

final class DAppSettingsViewLayout: UIView {
    let tableView: UITableView = .create {
        $0.registerClassForCell(DAppFavoriteSettingsView.self)
        $0.registerClassForCell(DAppDesktopModeSettingsView.self)
        $0.registerHeaderFooterView(withClass: IconTitleHeaderView.self)
        $0.separatorStyle = .none
        $0.rowHeight = 56
        $0.backgroundColor = .clear
        $0.contentInset = .init(top: 16, left: 16, bottom: 16, right: -16)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBottomSheetBackground()

        addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
