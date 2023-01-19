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
        let topView = UIView.vStack(spacing: 16, [
            bannerView,
            UIView.hStack([
                filterView,
                UIView(),
                sortView
            ])
        ])

        sortView.setContentCompressionResistancePriority(.required, for: .horizontal)
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
        addSubview(label)
        addSubview(control)

        label.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
        }

        control.snp.makeConstraints {
            $0.leading.equalTo(label.snp.trailing)
            $0.centerY.trailing.equalToSuperview()
        }
    }

    override var intrinsicContentSize: CGSize {
        .init(width: label.intrinsicContentSize.width + control.intrinsicContentSize.width + 4, height: UIView.noIntrinsicMetric)
    }

    func bind(title: String, value: String) {
        label.text = title
        control.iconDetailsView.detailsLabel.text = value
    }
}
