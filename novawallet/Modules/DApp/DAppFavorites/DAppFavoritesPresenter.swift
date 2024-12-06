import Foundation
import SoraFoundation
import Operation_iOS

final class DAppFavoritesPresenter {
    weak var view: DAppFavoritesViewProtocol?
    let wireframe: DAppFavoritesWireframeProtocol
    let interactor: DAppFavoritesInteractorInputProtocol
    let viewModelFactory: DAppListViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    private var favorites: [String: DAppFavorite] = [:]

    init(
        interactor: DAppFavoritesInteractorInputProtocol,
        wireframe: DAppFavoritesWireframeProtocol,
        viewModelFactory: DAppListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }
}

// MARK: Private

private extension DAppFavoritesPresenter {
    func provideDApps() {
        let viewModels = viewModelFactory.createFavoriteDApps(
            from: Array(favorites.values)
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
        // TODO: Implement routing

        print(id)
    }
}

// MARK: DAppFavoritesInteractorOutputProtocol

extension DAppFavoritesPresenter: DAppFavoritesInteractorOutputProtocol {
    func didReceiveFavorites(changes: [DataProviderChange<DAppFavorite>]) {
        let currentFavorites = favorites
        let updatedFavorites = changes.mergeToDict(currentFavorites)

        favorites = updatedFavorites

        guard currentFavorites.count != updatedFavorites.count else { return }

        provideDApps()
    }
}
