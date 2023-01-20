import UIKit
import SnapKit

final class AddDelegationViewLayout: UIView {
    let bannerView = DelegateBanner()
    let filterView = DelegationsControlView()
    let sortView = DelegationsControlView()

    lazy var topView = UIView.vStack(spacing: 16, [
        bannerView,
        UIView.hStack(distribution: .fillProportionally, [
            filterView,
            UIView(),
            sortView
        ])
    ])

    let tableView: UITableView = .create {
        $0.separatorStyle = .none
        $0.backgroundColor = .clear
        $0.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
        $0.registerClassForCell(DelegateTableViewCell.self)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(topView)
        topView.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top).offset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(topView.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview()
        }
    }
}
