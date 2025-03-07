import Operation_iOS

protocol DAppFavoritesViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [DAppViewModel])
}

protocol DAppFavoritesPresenterProtocol: AnyObject {
    func setup()
    func removeFavorite(with id: String)
    func reorderFavorites(reorderedModels: [DAppViewModel])
    func selectDApp(with id: String)
}

protocol DAppFavoritesInteractorInputProtocol: AnyObject {
    func setup()
    func reorderFavorites(
        _ favorites: [String: DAppFavorite],
        reorderedIds: [String]
    )
    func removeFavorite(with id: String)
}

protocol DAppFavoritesInteractorOutputProtocol: AnyObject {
    func didReceiveFavorites(changes: [DataProviderChange<DAppFavorite>])
    func didReceive(dAppsResult: Result<DAppList?, Error>)
}

protocol DAppFavoritesWireframeProtocol: DAppAlertPresentable, BrowserOpening {
    func close(from view: ControllerBackedProtocol?)
}
