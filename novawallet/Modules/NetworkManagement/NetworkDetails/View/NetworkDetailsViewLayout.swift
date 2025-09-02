import UIKit_iOS

final class NetworkDetailsViewLayout: UIView {
    let headerView: StackNetworkCell = .create { view in
        view.iconSize = .init(width: 32, height: 32)
        view.nameLabel.apply(style: .boldTitle2Primary)
    }

    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = R.color.colorSecondaryScreenBackground()
        view.separatorStyle = .none

        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()

        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.bottom.equalToSuperview()
        }

        headerView.snp.makeConstraints { make in
            make.height.equalTo(72)
        }

        tableView.tableHeaderView = headerView
        tableView.layoutIfNeeded()
    }
}

// MARK: Model

extension NetworkDetailsViewLayout {
    struct NodeModel {
        enum Ping: Equatable {
            case low(String)
            case medium(String)
            case high(String)
        }

        enum ConnectionState: Equatable {
            case connecting(String)
            case pinged(Ping)
            case disconnected
            case unknown(String)
        }

        enum Accessory: Equatable {
            case edit(String)
            case more
            case none
        }

        let id: UUID
        let name: String
        let url: String
        let connectionState: ConnectionState
        let selected: Bool
        let dimmed: Bool
        let custom: Bool
        let accessory: Accessory

        let onTapMore: ((UUID) -> Void)?
        let onTapEdit: ((UUID) -> Void)?
    }

    enum Row {
        case switcher(SelectableViewModel<TitleIconViewModel>)
        case addCustomNode(TitleIconViewModel)
        case node(NodeModel)
    }

    struct Section {
        let title: String?
        let rows: [Row]
    }

    struct Model {
        let customNetwork: Bool
        let networkViewModel: NetworkViewModel
        let sections: [Section]
    }
}
