import UIKit
import Foundation_iOS

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
        rootView.tableView.isEditing = true

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

// MARK: DAppFavoriteItemViewDelegate

extension DAppFavoritesViewController: DAppFavoriteItemViewDelegate {
    func didTapFavoriteButton(_ itemId: String) {
        presenter.removeFavorite(with: itemId)
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

        cell.contentDisplayView.delegate = self
        cell.contentDisplayView.bind(viewModel: viewModel)

        return cell
    }
}

// MARK: UITableViewDelegate

extension DAppFavoritesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let viewModel = viewModels[indexPath.row]

        presenter.selectDApp(with: viewModel.identifier)
    }

    func tableView(
        _: UITableView,
        heightForRowAt _: IndexPath
    ) -> CGFloat {
        64
    }

    func tableView(
        _: UITableView,
        moveRowAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        let movedDApp = viewModels[sourceIndexPath.row]
        viewModels.remove(at: sourceIndexPath.row)
        viewModels.insert(movedDApp, at: destinationIndexPath.row)

        presenter.reorderFavorites(reorderedModels: viewModels)
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
        shouldIndentWhileEditingRowAt _: IndexPath
    ) -> Bool {
        false
    }
}

// MARK: Localizable

extension DAppFavoritesViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupNavigationBar()
    }
}
