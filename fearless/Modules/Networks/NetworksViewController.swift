import UIKit
import SoraUI
import SoraFoundation

final class NetworksViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworksViewLayout

    let presenter: NetworksPresenterProtocol
    private var state: NetworksViewState?

    init(
        presenter: NetworksPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
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
        view = NetworksViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupTable()
        presenter.setup()
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale

        title = R.string.localizable
            .connectionManagementTitle(preferredLanguages: locale?.rLanguages)
    }

    private func setupTable() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(NetworksItemCell.self)
    }
}

extension NetworksViewController: NetworksViewProtocol {
    func reload(state: NetworksViewState) {
        self.state = state
        switch state {
        case .loaded:
            rootView.tableView.reloadData()
        default:
            print(state)
        }
    }
}

extension NetworksViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension NetworksViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard
            let state = state,
            case let NetworksViewState.loaded(viewModel) = state
        else { return 0 }
        return viewModel.sections[section].1.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let state = state,
            case let NetworksViewState.loaded(viewModel) = state
        else { return UITableViewCell() }
        let cell = tableView.dequeueReusableCellWithType(NetworksItemCell.self, forIndexPath: indexPath)
        let cellViewModel = viewModel.sections[indexPath.section].1[indexPath.row]
        cell.bind(viewModel: cellViewModel)
        return cell
    }
}

extension NetworksViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
