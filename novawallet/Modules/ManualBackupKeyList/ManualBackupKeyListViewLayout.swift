import UIKit

final class ManualBackupKeyListViewLayout: UIView {
    lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.separatorStyle = .none
        view.backgroundColor = .clear
        view.contentInset = .init(top: 0, left: 16, bottom: 0, right: 16)

        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.bottom.equalToSuperview()
        }
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
