import UIKit

final class DelegationListViewLayout: UIView {
    lazy var tableView: UITableView = .create {
        $0.separatorStyle = .none
        $0.backgroundColor = .clear
        $0.contentInset = .zero
        $0.rowHeight = UITableView.automaticDimension
        $0.showsVerticalScrollIndicator = false
        $0.contentInsetAdjustmentBehavior = .never
        $0.tableHeaderView = .init(frame: .init(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
        $0.sectionHeaderHeight = 0
        $0.sectionFooterHeight = 0
        $0.registerClassForCell(VersionTableViewCell.self)
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
