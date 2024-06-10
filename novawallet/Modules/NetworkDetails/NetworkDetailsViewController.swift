import UIKit

final class NetworkDetailsViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworkDetailsViewLayout
    typealias ViewModel = NetworkDetailsViewLayout.Model

    let presenter: NetworkDetailsPresenterProtocol

    private var viewModel: ViewModel?

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
}

// MARK: NetworkDetailsViewProtocol

extension NetworkDetailsViewController: NetworkDetailsViewProtocol {
    func update(with viewModel: NetworkDetailsViewLayout.Model) {
        self.viewModel = viewModel
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
                isOn: viewModel.selectable
            )

            cell = switchCell
        case let .addCustomNode(title):
            let titleCell = tableView.dequeueReusableCellWithType(SettingsTableViewCell.self)!
            titleCell.bind(titleViewModel: title)

            cell = titleCell
        case let .node(viewModel):
            return UITableViewCell()
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

        // TODO: Implement
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = viewModel?.sections[section].title else { return nil }

        let header: SettingsSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        header.titleLabel.text = title
        return header
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 0.0 : 37.0
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
        case 0:
            presenter.toggleEnabled()
        case 1:
            presenter.toggleConnectionMode()
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
        rootView.tableView.registerHeaderFooterView(withClass: SettingsSectionHeaderView.self)
    }
}
