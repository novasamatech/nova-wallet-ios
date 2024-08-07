import Foundation
import SoraFoundation
import Operation_iOS

final class DAppSearchPresenter {
    weak var view: DAppSearchViewProtocol?
    let wireframe: DAppSearchWireframeProtocol
    let interactor: DAppSearchInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    private var dAppList: DAppList?
    private var favorites: [String: DAppFavorite]?

    private(set) var query: String?

    weak var delegate: DAppSearchDelegate?

    let viewModelFactory: DAppListViewModelFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol

    let logger: LoggerProtocol?

    init(
        interactor: DAppSearchInteractorInputProtocol,
        wireframe: DAppSearchWireframeProtocol,
        viewModelFactory: DAppListViewModelFactoryProtocol,
        initialQuery: String?,
        delegate: DAppSearchDelegate,
        applicationConfig: ApplicationConfigProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        query = initialQuery
        self.delegate = delegate
        self.applicationConfig = applicationConfig
        self.localizationManager = localizationManager
        self.logger = logger
    }

    private func provideViewModel() {
        if let dAppList = dAppList, let favorites = favorites {
            let viewModels = viewModelFactory.createDAppsFromQuery(
                query,
                dAppList: dAppList,
                favorites: favorites
            )

            view?.didReceiveDApp(viewModels: viewModels)
        } else {
            view?.didReceiveDApp(viewModels: [])
        }
    }
}

extension DAppSearchPresenter: DAppSearchPresenterProtocol {
    func setup() {
        if let query = query {
            view?.didReceive(initialQuery: query)
        }

        interactor.setup()
    }

    func updateSearch(query: String) {
        self.query = query

        provideViewModel()
    }

    func selectDApp(viewModel: DAppViewModel) {
        guard let dAppList = dAppList else {
            return
        }

        switch viewModel.identifier {
        case let .index(value):
            let dApp = dAppList.dApps[value]
            delegate?.didCompleteDAppSearchResult(.dApp(model: dApp))
        case let .key(value):
            delegate?.didCompleteDAppSearchResult(.query(string: value))
        }

        wireframe.close(from: view)
    }

    func selectSearchQuery() {
        wireframe.showUnknownDappWarning(
            from: view,
            email: applicationConfig.supportEmail,
            locale: localizationManager.selectedLocale,
            handler: { [weak self] in
                self?.delegate?.didCompleteDAppSearchResult(
                    .query(string: self?.query ?? "")
                )
                self?.wireframe.close(from: self?.view)
            }
        )
    }

    func cancel() {
        wireframe.close(from: view)
    }
}

extension DAppSearchPresenter: DAppSearchInteractorOutputProtocol {
    func didReceive(dAppsResult: Result<DAppList?, Error>) {
        switch dAppsResult {
        case let .success(list):
            dAppList = list

            provideViewModel()
        case let .failure(error):
            logger?.error("Fatal error: \(error)")
        }
    }

    func didReceiveFavorite(changes: [DataProviderChange<DAppFavorite>]) {
        favorites = changes.mergeToDict(favorites ?? [:])

        provideViewModel()
    }
}
