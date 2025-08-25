import UIKit

final class BaseNotificationSettingsViewLayout: UIView {
    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = R.color.colorSecondaryScreenBackground()
        view.separatorStyle = .none
        view.sectionFooterHeight = 8
        view.sectionHeaderHeight = 0
        view.tableHeaderView = .init(frame: .init(
            x: 0,
            y: 0,
            width: 0,
            height: CGFloat.leastNonzeroMagnitude
        ))
        view.rowHeight = 55
        view.contentInsetAdjustmentBehavior = .never
        view.automaticallyAdjustsScrollIndicatorInsets = false
        view.contentInset = .init(top: 0, left: 0, bottom: 16, right: 0)
        view.contentOffset = .zero
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).inset(16)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
