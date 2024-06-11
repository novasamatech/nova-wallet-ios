import UIKit

final class NetworkDetailsViewLayout: UIView {
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
            case pinged(Ping)
        }

        let index: Int
        let name: String
        let url: String
        let connectionState: ConnectionState
        let selected: Bool
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
