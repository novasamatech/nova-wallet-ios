import UIKit
import SoraFoundation

final class DAppFavoritesViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppFavoritesViewLayout

    let presenter: DAppFavoritesPresenterProtocol

    private var viewModels: [DAppViewModel] = []

    init(
        presenter: DAppFavoritesPresenterProtocol,
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
        view = DAppFavoritesViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setup()
    }
}

// MARK: Private

private extension DAppFavoritesViewController {
    func setup() {
        setupTableView()
        setupNavigationBar()
    }

    func setupTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.tableView.registerClassForCell(DAppFavoriteItemTableViewCell.self)
    }

    func setupNavigationBar() {
        navigationItem.title = R.string.localizable.commonFavorites(
            preferredLanguages: selectedLocale.rLanguages
        )
    }
}

// MARK: DAppFavoritesViewProtocol

extension DAppFavoritesViewController: DAppFavoritesViewProtocol {
    func didReceive(viewModels: [DAppViewModel]) {
        self.viewModels = viewModels

        rootView.tableView.reloadData()
    }
}

// MARK: UITableViewDataSource

extension DAppFavoritesViewController: UITableViewDataSource {
    func tableView(
        _: UITableView,
        numberOfRowsInSection _: Int
    ) -> Int {
        viewModels.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell: DAppFavoriteItemTableViewCell = tableView.dequeueReusableCellWithType(
            DAppFavoriteItemTableViewCell.self
        )!
        let viewModel = viewModels[indexPath.row]

        cell.contentDisplayView.bind(viewModel: viewModel)

        return cell
    }
}

// MARK: UITableViewDelegate

extension DAppFavoritesViewController: UITableViewDelegate {
    func tableView(
        _: UITableView,
        heightForRowAt _: IndexPath
    ) -> CGFloat {
        64
    }

    func tableView(
        _: UITableView,
        canMoveRowAt _: IndexPath
    ) -> Bool {
        true
    }

    func tableView(
        _: UITableView,
        targetIndexPathForMoveFromRowAt _: IndexPath,
        toProposedIndexPath proposedDestinationIndexPath: IndexPath
    ) -> IndexPath {
        proposedDestinationIndexPath
    }

    func tableView(
        _: UITableView,
        editingStyleForRowAt _: IndexPath
    ) -> UITableViewCell.EditingStyle {
        .none
    }

    func tableView(
        _: UITableView,
        commit _: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        print(indexPath)
    }
}

// MARK: Localizable

extension DAppFavoritesViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupNavigationBar()
    }
}
