import UIKit

final class ManualBackupKeyListViewLayout: UIView, TableHeaderLayoutUpdatable {
    lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .insetGrouped)
        view.separatorStyle = .none
        view.backgroundColor = .clear
        view.sectionFooterHeight = 0
        view.directionalLayoutMargins = .init(
            top: 0,
            leading: 16,
            bottom: 0,
            trailing: 16
        )

        return view
    }()

    let headerView: MultiValueView = {
        let view = MultiValueView.createTableHeaderView()
        view.stackView.layoutMargins.bottom = 0

        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
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
        updateTableHeaderLayout(headerView)
    }
}

// MARK: Private

private extension ManualBackupKeyListViewLayout {
    func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        tableView.tableHeaderView = headerView
    }

    func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }
}

// MARK: Model

extension ManualBackupKeyListViewLayout {
    struct CustomAccountsSection {
        let headerText: String
        let accounts: [CustomAccount]
    }

    struct DefaultAccountsSection {
        let headerText: String
        let accounts: [DefaultAccount]
    }

    struct DefaultAccount {
        let title: String
        let subtitle: String
    }

    struct CustomAccount {
        let network: NetworkViewModel
        let chainId: ChainModel.Id
    }

    enum Sections {
        case defaultKeys(DefaultAccountsSection)
        case customKeys(CustomAccountsSection)
    }

    struct Model {
        let listHeaderText: String
        let accountsSections: [Sections]
    }
}
