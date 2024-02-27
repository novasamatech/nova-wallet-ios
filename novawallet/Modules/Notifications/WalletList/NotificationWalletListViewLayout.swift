import UIKit

final class NotificationWalletListViewLayout: WalletsListViewLayout, TableHeaderLayoutUpdatable {
    let headerView = MultiValueView.createTableHeaderView()
    let actionButton: LoadableActionView = .create {
        $0.actionButton.applyDefaultStyle()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        tableView.tableHeaderView = headerView
        tableView.contentInset = .init(
            top: 0,
            left: 0,
            bottom: UIConstants.actionHeight + 8,
            right: 0
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupLayout() {
        super.setupLayout()

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        updateTableHeaderLayout(headerView)
    }
}
