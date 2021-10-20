import UIKit

final class NetworkDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworkDetailsViewLayout

    let presenter: NetworkDetailsPresenterProtocol
    private var viewModel: NetworkDetailsViewModel?

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

        setupTable()
        presenter.setup()
    }

    private func setupTable() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(SwitchTableViewCell.self)
        rootView.tableView.registerClassForCell(NodeConnectionCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: NetworksSectionHeaderView.self)
    }
}

extension NetworkDetailsViewController: NetworkDetailsViewProtocol {
    func reload(viewModel: NetworkDetailsViewModel) {
        self.viewModel = viewModel
        title = viewModel.title
        rootView.tableView.reloadData()
    }
}

extension NetworkDetailsViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        switch viewModel.sections[section] {
        case .autoSelectNodes:
            return 1
        case let .customNodes(cellViewModels), let .defaultNodes(cellViewModels):
            return cellViewModels.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel else { return UITableViewCell() }

        switch viewModel.sections[indexPath.section] {
        case let .autoSelectNodes(select):
            let cell = tableView.dequeueReusableCellWithType(SwitchTableViewCell.self, forIndexPath: indexPath)
            cell.bind(title: "Auto", isOn: select)
            return cell
        case let .customNodes(cellViewModels), let .defaultNodes(cellViewModels):
            let cell = tableView.dequeueReusableCellWithType(NodeConnectionCell.self, forIndexPath: indexPath)
            let cellViewModel = cellViewModels[indexPath.row]
            cell.bind(viewModel: cellViewModel)
            return cell
        }
    }

    func tableView(_: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        UIView()
    }
}

extension NetworkDetailsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
