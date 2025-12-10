import UIKit

final class HardwareWalletAddressesViewLayout: UIView, TableHeaderLayoutUpdatable {
    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.changesContentOpacityWhenHighlighted = true
        return button
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.separatorStyle = .none
        return view
    }()

    let headerView = MultiValueView.createTableHeaderView()

    var titleLabel: UILabel { headerView.valueTop }
    var subtitleLabel: UILabel { headerView.valueBottom }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        updateTableHeaderLayout(headerView)
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.bottom.equalToSuperview()
        }

        tableView.tableHeaderView = headerView

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }

        let bottomInset = UIConstants.actionBottomInset + UIConstants.actionHeight + 16.0
        tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0)
    }
}
