import Foundation
import Foundation_iOS
import Operation_iOS

final class DAppFavoritesPresenter {
    weak var view: DAppFavoritesViewProtocol?
    let wireframe: DAppFavoritesWireframeProtocol
    let interactor: DAppFavoritesInteractorInputProtocol
    let viewModelFactory: DAppListViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol
    let logger: LoggerProtocol

    let metaId: MetaAccountModel.Id

    private var favorites: [String: DAppFavorite] = [:]
    private var dAppList: DAppList?

    init(
        interactor: DAppFavoritesInteractorInputProtocol,
        wireframe: DAppFavoritesWireframeProtocol,
        viewModelFactory: DAppListViewModelFactoryProtocol,
        metaId: MetaAccountModel.Id,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.metaId = metaId
        self.localizationManager = localizationManager
        self.logger = logger
    }
}

// MARK: Private

private extension DAppFavoritesPresenter {
    func provideDApps() {
        guard let dAppList else { return }

        let viewModels = viewModelFactory.createFavoriteDApps(
            from: Array(favorites.values),
            dAppList: dAppList
        )

        view?.didReceive(viewModels: viewModels)
    }
}

// MARK: DAppFavoritesPresenterProtocol

extension DAppFavoritesPresenter: DAppFavoritesPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func removeFavorite(with id: String) {
        wireframe.showFavoritesRemovalConfirmation(
            from: view,
            name: favorites[id]?.label ?? "",
            locale: localizationManager.selectedLocale
        ) { [weak self] in
            self?.interactor.removeFavorite(with: id)
        }
    }

    func reorderFavorites(reorderedModels: [DAppViewModel]) {
        let ids = reorderedModels.map(\.identifier)

        interactor.reorderFavorites(
            favorites,
            reorderedIds: ids
        )
    }

    func selectDApp(with id: String) {
        wireframe.openBrowser(with: id)
    }
}

// MARK: DAppFavoritesInteractorOutputProtocol

extension DAppFavoritesPresenter: DAppFavoritesInteractorOutputProtocol {
    func didReceive(dAppsResult: Result<DAppList?, any Error>) {
        switch dAppsResult {
        case let .success(list):
            dAppList = list

            provideDApps()
        case let .failure(error):
            logger.error("Fatal error: \(error)")
        }
    }

    func didReceiveFavorites(changes: [DataProviderChange<DAppFavorite>]) {
        let currentFavorites = favorites
        let updatedFavorites = changes.mergeToDict(currentFavorites)

        guard !updatedFavorites.isEmpty else {
            wireframe.close(from: view)

            return
        }

        favorites = updatedFavorites

        guard currentFavorites.count != updatedFavorites.count else { return }

        provideDApps()
    }
}
