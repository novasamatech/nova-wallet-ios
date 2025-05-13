import Foundation
import Operation_iOS

final class DAppListInteractor {
    weak var presenter: DAppListInteractorOutputProtocol?

    let dAppProvider: AnySingleValueProvider<DAppList>
    let dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol
    let dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>
    let phishingSyncService: ApplicationServiceProtocol
    let logger: LoggerProtocol

    private var favoriteDAppsProvider: StreamableProvider<DAppFavorite>?

    init(
        dAppProvider: AnySingleValueProvider<DAppList>,
        phishingSyncService: ApplicationServiceProtocol,
        dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol,
        dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>,
        logger: LoggerProtocol
    ) {
        self.dAppProvider = dAppProvider
        self.phishingSyncService = phishingSyncService
        self.dAppsLocalSubscriptionFactory = dAppsLocalSubscriptionFactory
        self.dAppsFavoriteRepository = dAppsFavoriteRepository
        self.logger = logger
    }

    deinit {
        phishingSyncService.throttle()
    }

    private func subscribeDApps() {
        let updateClosure: ([DataProviderChange<DAppList>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                self?.presenter?.didReceive(dAppsResult: .success(result))
            } else {
                self?.presenter?.didReceive(dAppsResult: nil)
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter?.didReceive(dAppsResult: .failure(error))
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true, waitsInProgressSyncOnAdd: false)

        dAppProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }
}

// MARK: DAppListInteractorInputProtocol

extension DAppListInteractor: DAppListInteractorInputProtocol {
    func setup() {
        subscribeDApps()

        favoriteDAppsProvider = subscribeToFavoriteDApps(nil)

        phishingSyncService.setup()
    }

    func refresh() {
        dAppProvider.refresh()
    }
}

// MARK: DAppLocalStorageSubscriber

extension DAppListInteractor: DAppLocalStorageSubscriber, DAppLocalSubscriptionHandler {
    func handleFavoriteDApps(result: Result<[DataProviderChange<DAppFavorite>], Error>) {
        switch result {
        case let .success(changes):
            presenter?.didReceiveFavoriteDapp(changes: changes)
        case let .failure(error):
            logger.error("Unexpected favorites error: \(error)")
        }
    }
}
