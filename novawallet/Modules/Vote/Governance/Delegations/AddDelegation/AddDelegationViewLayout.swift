import UIKit
import SnapKit

final class AddDelegationViewLayout: UIView {
    let bannerView = DelegateBanner()
    let filterView: DelegationsControlView = .create {
        $0.bind(title: "Show:", value: "All accounts")
    }

    let sortView: DelegationsControlView = .create {
        $0.bind(title: "Sort by:", value: "Delegations")
    }

    lazy var controlsView = UIView.hStack([
        filterView,
        FlexibleSpaceView(),
        sortView
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
        addSubview(bannerView)
        bannerView.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top).offset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        addSubview(controlsView)
        controlsView.snp.makeConstraints {
            $0.top.equalTo(bannerView.snp.bottom).offset(16)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.height.equalTo(32)
        }
        addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(controlsView.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview()
        }
    }
}

final class DelegationsControlView: UIView {
    let label = UILabel(style: .footnoteSecondary)
    let control: YourWalletsControl = .create {
        $0.color = R.color.colorTextPrimary()!
        $0.iconDetailsView.detailsLabel.apply(style: .footnotePrimary)
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
        let stack = UIView.hStack([
            label,
            control
        ])
        stack.spacing = 4
        addSubview(stack)
        label.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .horizontal)
        stack.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func bind(title: String, value: String) {
        label.text = title
        control.iconDetailsView.detailsLabel.text = value
        control.invalidateLayout()
        control.setNeedsLayout()
    }
}
