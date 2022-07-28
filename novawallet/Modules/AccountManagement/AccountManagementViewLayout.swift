import Foundation
import UIKit

final class AccountManagementViewLayout: UIView {
    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.separatorStyle = .none
        return view
    }()

    let headerView = AccountManagementHeaderView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        updateHeaderLayout()
    }

    func updateHeaderLayout() {
        let height = headerView.systemLayoutSizeFitting(
            CGSize(width: bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        let size = CGSize(width: bounds.width, height: height)
        if size != headerView.frame.size {
            headerView.frame = CGRect(origin: .zero, size: size)
        }
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.bottom.equalToSuperview()
        }

        tableView.tableHeaderView = headerView
    }
}
