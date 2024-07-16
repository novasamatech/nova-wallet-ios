import UIKit

final class NetworkDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworkDetailsViewLayout
    typealias ViewModel = NetworkDetailsViewLayout.Model

    let presenter: NetworkDetailsPresenterProtocol

    private var viewModel: ViewModel?
    private var nodesViewModels: [UUID: RootViewType.NodeModel] = [:]
    private var nodesIndexPaths: [UUID: IndexPath] = [:]

    init(presenter: NetworkDetailsPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NetworkDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        rootView.tableView.reloadData()
    }
}

// MARK: NetworkDetailsViewProtocol

extension NetworkDetailsViewController: NetworkDetailsViewProtocol {
    func updateNodes(with viewModel: NetworkDetailsViewLayout.Section) {
        viewModel
            .rows
            .forEach { row in
                guard
                    case let .node(nodeModel) = row,
                    let indexPath = nodesIndexPaths[nodeModel.id]
                else {
                    return
                }

                let cell = rootView.tableView.cellForRow(at: indexPath) as? NetworkDetailsNodeTableViewCell
                cell?.bind(viewModel: nodeModel)
                nodesViewModels[nodeModel.id] = nodeModel
            }
    }

    func update(with viewModel: NetworkDetailsViewLayout.Model) {
        self.viewModel = viewModel

        if viewModel.customNetwork {
            setupActions()
        }

        nodesViewModels = extractNodesViewModels(from: viewModel)
        cacheIndexPaths(from: viewModel)

        rootView.headerView.bind(viewModel: viewModel.networkViewModel)
        rootView.tableView.reloadData()
    }
}

// MARK: UITableViewDataSource

extension NetworkDetailsViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        viewModel?.sections.count ?? 0
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel?.sections[section].rows.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel else { return UITableViewCell() }

        let section = viewModel.sections[indexPath.section]
        let row = section.rows[indexPath.row]

        let cell: UITableViewCell & TableViewCellPositioning

        switch row {
        case let .switcher(viewModel):
            let switchCell = tableView.dequeueReusableCellWithType(SwitchSettingsTableViewCell.self)!

            switchCell.delegate = self
            switchCell.bind(
                titleViewModel: viewModel.underlyingViewModel,
                isOn: viewModel.selectable,
                isEnabled: viewModel.enabled
            )

            cell = switchCell
        case let .addCustomNode(title):
            let titleCell = tableView.dequeueReusableCellWithType(SettingsTableViewCell.self)!
            titleCell.bind(titleViewModel: title)
            titleCell.titleLabel.textColor = R.color.colorButtonTextAccent()!

            cell = titleCell
        case let .node(model):
            guard let viewModel = nodesViewModels[model.id] else {
                return UITableViewCell()
            }

            let nodeCell = tableView.dequeueReusableCellWithType(NetworkDetailsNodeTableViewCell.self)!
            nodeCell.bind(viewModel: viewModel)

            cell = nodeCell
        }

        cell.apply(
            position: .init(
                row: indexPath.row,
                count: section.rows.count
            )
        )

        return cell
    }
}

// MARK: UITableViewDelegate

extension NetworkDetailsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel else { return }

        tableView.deselectRow(at: indexPath, animated: true)

        let section = viewModel.sections[indexPath.section]
        let row = section.rows[indexPath.row]

        switch row {
        case let .node(model):
            presenter.selectNode(with: model.id)
        case .addCustomNode:
            presenter.addNode()
        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = viewModel?.sections[section].title else { return nil }

        let header: SettingsSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        header.titleLabel.text = title
        return header
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? .zero : Constants.headerHeight
    }
}

// MARK: SwitchSettingsTableViewCellDelegate

extension NetworkDetailsViewController: SwitchSettingsTableViewCellDelegate {
    func didToggle(cell: SwitchSettingsTableViewCell) {
        guard
            let indexPath = rootView.tableView.indexPath(for: cell),
            let section = viewModel?.sections[indexPath.section],
            case .switcher = section.rows[indexPath.row]
        else {
            return
        }

        switch indexPath.row {
        case Constants.connectionStateRowIndex:
            presenter.setNetwork(enabled: cell.rightView.isOn)
        case Constants.connectionModeRowIndex:
            presenter.setAutoBalance(enabled: cell.rightView.isOn)
        default:
            break
        }
    }
}

// MARK: Private

private extension NetworkDetailsViewController {
    func setup() {
        setupTableView()
    }

    func setupTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(SwitchSettingsTableViewCell.self)
        rootView.tableView.registerClassForCell(SettingsTableViewCell.self)
        rootView.tableView.registerClassForCell(NetworkDetailsNodeTableViewCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: SettingsSectionHeaderView.self)
    }

    func setupActions() {
        let rightBarButtonItem = UIBarButtonItem(
            image: R.image.iconMore(),
            style: .plain,
            target: self,
            action: #selector(actionMore)
        )

        navigationItem.rightBarButtonItem = rightBarButtonItem
    }

    func extractNodesViewModels(from viewModel: ViewModel) -> [UUID: RootViewType.NodeModel] {
        viewModel.sections
            .flatMap(\.rows)
            .reduce(into: [:]) { acc, row in
                guard case let .node(nodeModel) = row else { return }

                acc[nodeModel.id] = nodeModel
            }
    }

    func cacheIndexPaths(from viewModel: ViewModel) {
        var customNodeIndex = 1
        var remoteNodeIndex = 0

        viewModel.sections
            .flatMap(\.rows)
            .compactMap { row -> RootViewType.NodeModel? in
                guard case let .node(nodeModel) = row else { return nil }

                return nodeModel
            }
            .forEach { node in
                if node.custom {
                    nodesIndexPaths[node.id] = IndexPath(
                        row: customNodeIndex,
                        section: Constants.customNodesSectionIndex
                    )
                    customNodeIndex += 1
                } else {
                    nodesIndexPaths[node.id] = IndexPath(
                        row: remoteNodeIndex,
                        section: Constants.remoteNodesSectionIndex
                    )
                    remoteNodeIndex += 1
                }
            }
    }

    @objc private func actionMore() {
        presenter.manageNetwork()
    }
}

extension NetworkDetailsViewController {
    enum Constants {
        static let customNodesSectionIndex: Int = 1
        static let remoteNodesSectionIndex: Int = 2
        static let connectionStateRowIndex: Int = 0
        static let connectionModeRowIndex: Int = 1
        static let headerHeight: CGFloat = 37.0
        static let networkIconSize = CGSize(
            width: 32,
            height: 32
        )
    }
}
