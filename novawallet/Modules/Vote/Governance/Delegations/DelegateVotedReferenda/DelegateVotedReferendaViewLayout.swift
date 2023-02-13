import UIKit

final class DelegateVotedReferendaViewLayout: UIView {
    var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.separatorStyle = .none
        view.backgroundColor = .clear
        view.contentInset = .zero
        view.rowHeight = UITableView.automaticDimension
        view.allowsSelection = false
        view.showsVerticalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .never
        view.tableHeaderView = .init(frame: .init(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
        view.sectionHeaderHeight = 0
        view.sectionFooterHeight = 8
        view.registerClassForCell(ReferendumTableViewCell.self)
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
        tableView.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top).inset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalTo(safeAreaLayoutGuide).inset(16)
        }
    }
}
