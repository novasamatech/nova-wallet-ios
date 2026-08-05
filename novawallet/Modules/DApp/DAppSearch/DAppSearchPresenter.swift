import Foundation
import Foundation_iOS
import Operation_iOS

final class DAppSearchPresenter: DAppSearchingByQuery {
    weak var view: DAppSearchViewProtocol?
    let wireframe: DAppSearchWireframeProtocol
    let interactor: DAppSearchInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    private var dAppList: DAppList?
    private var favorites: [String: DAppFavorite]?

    private(set) var query: String?
    private(set) var selectedCategoryId: String?

    weak var delegate: DAppSearchDelegate?

    let viewModelFactory: DAppListViewModelFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol

    let logger: LoggerProtocol?

    init(
        interactor: DAppSearchInteractorInputProtocol,
        wireframe: DAppSearchWireframeProtocol,
        viewModelFactory: DAppListViewModelFactoryProtocol,
        initialQuery: String?,
        selectedCategoryId: String?,
        delegate: DAppSearchDelegate,
        applicationConfig: ApplicationConfigProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        query = initialQuery
        self.selectedCategoryId = selectedCategoryId
        self.delegate = delegate
        self.applicationConfig = applicationConfig
        self.localizationManager = localizationManager
        self.logger = logger
    }

    private func provideViewModel() {
        if let dAppList, let favorites {
            let viewModel = viewModelFactory.createDApps(
                from: selectedCategoryId,
                query: query,
                dAppList: dAppList,
                favorites: favorites
            )

            view?.didReceive(viewModel: viewModel)
        } else {
            view?.didReceive(viewModel: nil)
        }
    }

    private func provideStakingBanner() {
        view?.didReceive(stakingBannerVisible: DAppStakingDetection.isStakingQuery(query))
    }
}

// MARK: DAppSearchPresenterProtocol

extension DAppSearchPresenter: DAppSearchPresenterProtocol {
    func selectCategory(with id: String?) {
        selectedCategoryId = id
        provideViewModel()
    }

    func setup() {
        if let query = query {
            view?.didReceive(initialQuery: query)
        }

        provideStakingBanner()

        interactor.setup()
    }

    func updateSearch(query: String) {
        self.query = query

        provideViewModel()
        provideStakingBanner()
    }

    func activateStaking() {
        wireframe.redirectToStaking(from: view)
    }

    func selectDApp(viewModel: DAppViewModel) {
        guard let dAppList = dAppList else {
            return
        }

        let result: DAppSearchResult = if let dApp = dAppList.dApps.first(
            where: { $0.identifier == viewModel.identifier }
        ) {
            .dApp(model: dApp)
        } else {
            .query(string: viewModel.identifier)
        }

        // the delegate might present a screen from the underlying view,
        // so it must be notified only after the search is dismissed
        wireframe.close(from: view) { [weak self] in
            self?.delegate?.didCompleteDAppSearchResult(result)
        }
    }

    func selectSearchQuery() {
        let proceedClosure: () -> Void = { [weak self] in
            self?.wireframe.close(from: self?.view) {
                self?.delegate?.didCompleteDAppSearchResult(
                    .query(string: self?.query ?? "")
                )
            }
        }

        guard search(by: query, in: dAppList).isEmpty else {
            proceedClosure()

            return
        }

        wireframe.showUnknownDappWarning(
            from: view,
            email: applicationConfig.supportEmail,
            locale: localizationManager.selectedLocale,
            handler: proceedClosure
        )
    }

    func cancel() {
        wireframe.close(from: view)
    }
}

// MARK: DAppSearchInteractorOutputProtocol

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
