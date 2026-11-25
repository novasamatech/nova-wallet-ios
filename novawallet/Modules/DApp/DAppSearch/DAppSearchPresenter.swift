import Foundation
import Foundation_iOS
import Operation_iOS
import NovaAnalytics

final class DAppSearchPresenter: DAppSearchingByQuery {
    weak var view: DAppSearchViewProtocol?
    let wireframe: DAppSearchWireframeProtocol
    let interactor: DAppSearchInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    var dAppList: DAppList?
    private var favorites: [String: DAppFavorite]?

    private(set) var query: String?
    private(set) var selectedCategoryId: String?
    private var stakingQueryKind: DAppStakingQueryKind = .none

    weak var delegate: DAppSearchDelegate?

    let viewModelFactory: DAppListViewModelFactoryProtocol
    let applicationConfig: ApplicationConfigProtocol
    let analyticsTracker: AnalyticsTrackingProtocol

    let logger: LoggerProtocol?

    init(
        interactor: DAppSearchInteractorInputProtocol,
        wireframe: DAppSearchWireframeProtocol,
        viewModelFactory: DAppListViewModelFactoryProtocol,
        initialQuery: String?,
        selectedCategoryId: String?,
        delegate: DAppSearchDelegate,
        applicationConfig: ApplicationConfigProtocol,
        analyticsTracker: AnalyticsTrackingProtocol,
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
        self.analyticsTracker = analyticsTracker
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
        let previousKind = stakingQueryKind
        stakingQueryKind = DAppStakingDetection.queryKind(query)

        view?.didReceive(stakingBannerVisible: stakingQueryKind != .none)

        // recorded when the banner appears or changes its kind, never per typed character;
        // the query itself must not be recorded
        if stakingQueryKind != previousKind {
            trackDAppStakingPromptShown(
                placement: .searchBanner,
                kind: stakingQueryKind.analyticsPromptKind,
                host: nil
            )
        }
    }

    // the classification happens here because this is the only delegate-independent
    // place that has the curated dApp list; the delegate might present a screen from
    // the underlying view, so it is notified only after the search is dismissed
    private func completeSearch(with result: DAppSearchResult) {
        let noticeContext = DAppStakingNoticeContext(
            kind: DAppStakingDetection.stakingSiteKind(result: result, dAppList: dAppList),
            host: analyticsHost(for: result)
        )

        wireframe.close(from: view) { [weak self] in
            self?.delegate?.didCompleteDAppSearchResult(result, noticeContext: noticeContext)
        }
    }
}

// MARK: DAppSearchPresenterProtocol

extension DAppSearchPresenter: DAppSearchPresenterProtocol {
    func selectCategory(with id: String?) {
        selectedCategoryId = id
        provideViewModel()
    }

    func setup() {
        trackFeatureOpened(.dapps)

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
        trackDAppStakingPromptAction(
            placement: .searchBanner,
            kind: stakingQueryKind.analyticsPromptKind,
            action: .goToStaking,
            host: nil
        )

        switch stakingQueryKind {
        case .bittensor:
            wireframe.redirectToBittensorStaking(from: view, source: .dappSearchBanner)
        case .staking, .none:
            wireframe.redirectToStaking(from: view)
        }
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

        trackDAppRowOpened(with: result)

        completeSearch(with: result)
    }

    func selectSearchQuery() {
        let proceedClosure: () -> Void = { [weak self] in
            guard let self else {
                return
            }

            let searchQuery = query ?? ""

            trackSearchQueryOpened(searchQuery)
            completeSearch(with: .query(string: searchQuery))
        }

        // a TAO-related address gets the Bittensor notice in place of the unknown dApp warning
        let isBittensorSite = DAppStakingDetection.isBittensorSite(result: .query(string: query ?? ""))

        guard search(by: query, in: dAppList).isEmpty, !isBittensorSite else {
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
