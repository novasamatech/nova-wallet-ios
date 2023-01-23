import UIKit
import SnapKit

final class AddDelegationViewLayout: UIView {
    let bannerView = GovernanceDelegateBanner()
    let filterView = GovernanceDelegatePresentationControlView()
    let sortView = GovernanceDelegatePresentationControlView()

    lazy var topView = UIView.vStack(spacing: 16, [
        bannerView,
        UIView.hStack(distribution: .fill, [
            filterView,
            UIView(),
            sortView
        ])
    ])

    let tableView: UITableView = .create {
        $0.separatorStyle = .none
        $0.backgroundColor = .clear
        $0.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
        $0.registerClassForCell(GovernanceDelegateTableViewCell.self)
        $0.rowHeight = UITableView.automaticDimension
    }

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
        addSubview(topView)
        topView.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top).offset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(topView.snp.bottom).offset(0)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview()
        }

        [filterView, sortView].forEach {
            $0.snp.makeConstraints { make in
                make.height.equalTo(32)
            }
        }
    }
}
