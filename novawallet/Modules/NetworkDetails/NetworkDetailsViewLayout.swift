import UIKit

final class NetworkDetailsViewLayout: UIView {
    let tableView: UITableView = .create { view in
        view.backgroundColor = R.color.colorSecondaryScreenBackground()
        view.separatorStyle = .none
    }

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
            make.edges.equalToSuperview()
        }
    }
}

// MARK: Model

extension NetworkDetailsViewLayout {
    struct NodeModel {
        enum Ping {
            case low(String)
            case medium(String)
            case high(String)
        }

        enum ConnectionState {
            case connecting(String)
            case connected(Ping)
        }

        let index: Int
        let url: String
        let connectionState: ConnectionState
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
        let sections: [Section]
    }
}
