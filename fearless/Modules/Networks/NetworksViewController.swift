import UIKit
import SoraUI
import SoraFoundation

final class NetworksViewController: UIViewController, ViewHolder {
    typealias RootViewType = NetworksViewLayout

    let presenter: NetworksPresenterProtocol
    private var viewModel: NetworksViewModel?

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
        rootView.tableView.registerHeaderFooterView(withClass: NetworksSectionHeaderView.self)
    }
}

extension NetworksViewController: NetworksViewProtocol {
    func reload(viewModel: NetworksViewModel) {
        self.viewModel = viewModel
        rootView.tableView.reloadData()
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
    func numberOfSections(in _: UITableView) -> Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.sections[section].1.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel else { return UITableViewCell() }

        let cell = tableView.dequeueReusableCellWithType(NetworksItemCell.self, forIndexPath: indexPath)
        let cellViewModel = viewModel.sections[indexPath.section].1[indexPath.row]
        cell.bind(viewModel: cellViewModel)
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let viewModel = viewModel else { return nil }

        let header: NetworksSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        let sectionTitle = viewModel.sections[section].0.title(for: selectedLocale)
        header.titleLabel.text = sectionTitle

        return header
    }
}

extension NetworksViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
