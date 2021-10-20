import UIKit
import SoraFoundation

final class NetworkDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworkDetailsViewLayout

    let presenter: NetworkDetailsPresenterProtocol
    private var viewModel: NetworkDetailsViewModel?

    init(
        presenter: NetworkDetailsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
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
        setupNavigationItem()
        rootView.actionButton.addTarget(self, action: #selector(handleActionButton), for: .touchUpInside)
        applyLocalization()
        presenter.setup()
    }

    private func setupTable() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(SwitchTableViewCell.self)
        rootView.tableView.registerClassForCell(NodeConnectionCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: NetworksSectionHeaderView.self)
    }

    private func setupNavigationItem() {
        let rightBarButtonItem = UIBarButtonItem(
            title: "",
            style: .plain,
            target: self,
            action: #selector(actionEdit)
        )

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite()!,
            .font: UIFont.h5Title
        ]

        rightBarButtonItem.setTitleTextAttributes(attributes, for: .normal)
        rightBarButtonItem.setTitleTextAttributes(attributes, for: .highlighted)

        navigationItem.rightBarButtonItem = rightBarButtonItem
        updateRightItem()
    }

    @objc
    private func actionEdit() {
        let tableView = rootView.tableView
        tableView.setEditing(!tableView.isEditing, animated: true)
        updateRightItem()

        for cell in tableView.visibleCells where
            tableView.indexPath(for: cell)?.section == viewModel?.customNodesSectionIndex {
            if let nodeCell = cell as? NodeConnectionCell {
                nodeCell.setReordering(tableView.isEditing, animated: true)
            }
        }
    }

    private func updateRightItem() {
        if rootView.tableView.isEditing {
            navigationItem.rightBarButtonItem?.title = R.string.localizable
                .commonDone(preferredLanguages: selectedLocale.rLanguages)
        } else {
            navigationItem.rightBarButtonItem?.title = R.string.localizable
                .commonEdit(preferredLanguages: selectedLocale.rLanguages)
        }
    }

    @objc
    private func handleActionButton() {
        presenter.handleActionButton()
    }
}

extension NetworkDetailsViewController: Localizable {
    func applyLocalization() {}
}

extension NetworkDetailsViewController: NetworkDetailsViewProtocol {
    func reload(viewModel: NetworkDetailsViewModel) {
        self.viewModel = viewModel
        title = viewModel.title
        rootView.tableView.reloadData()
        rootView.actionButton.imageWithTitleView?.title = viewModel.actionTitle
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
            cell.delegate = self
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

    func tableView(
        _: UITableView,
        editingStyleForRowAt indexPath: IndexPath
    ) -> UITableViewCell.EditingStyle {
        guard
            let viewModel = viewModel,
            indexPath.section == viewModel.customNodesSectionIndex
        else {
            return .none
        }

        if case let NetworkDetailsSection.customNodes(custom) = viewModel.sections[indexPath.section] {
            return custom[indexPath.row].isSelected ? .delete : .none
        }
        return .none
    }

    func tableView(_: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let viewModel = viewModel else { return false }
        if case NetworkDetailsSection.customNodes = viewModel.sections[indexPath.section] {
            return true
        }
        return false
    }
}

extension NetworkDetailsViewController: NodeConnectionCellDelegate {
    func didSelectInfo(_ cell: NodeConnectionCell) {
        print(cell)
    }
}
