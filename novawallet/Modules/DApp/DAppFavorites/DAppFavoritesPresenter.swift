import Foundation
import Operation_iOS

final class DAppFavoritesPresenter {
    weak var view: DAppFavoritesViewProtocol?
    let wireframe: DAppFavoritesWireframeProtocol
    let interactor: DAppFavoritesInteractorInputProtocol
    let viewModelFactory: DAppListViewModelFactoryProtocol

    private var favorites: [String: DAppFavorite] = [:]

    init(
        interactor: DAppFavoritesInteractorInputProtocol,
        wireframe: DAppFavoritesWireframeProtocol,
        viewModelFactory: DAppListViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
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
        interactor.removeFavorite(with: id)
    }
}

// MARK: DAppFavoritesInteractorOutputProtocol

extension DAppFavoritesPresenter: DAppFavoritesInteractorOutputProtocol {
    func didReceiveFavorites(changes: [DataProviderChange<DAppFavorite>]) {
        favorites = changes.mergeToDict(favorites)

        provideDApps()
    }
}
