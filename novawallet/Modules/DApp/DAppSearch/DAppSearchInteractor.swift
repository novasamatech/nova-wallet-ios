import Foundation
import RobinHood

final class DAppSearchInteractor {
    weak var presenter: DAppSearchInteractorOutputProtocol!

    let dAppProvider: AnySingleValueProvider<DAppList>
    let dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol
    let logger: LoggerProtocol

    private var favoriteDAppsProvider: StreamableProvider<DAppFavorite>?

    init(
        dAppProvider: AnySingleValueProvider<DAppList>,
        dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.dAppProvider = dAppProvider
        self.dAppsLocalSubscriptionFactory = dAppsLocalSubscriptionFactory
        self.logger = logger
    }

    private func subscribeDApps() {
        let updateClosure: ([DataProviderChange<DAppList>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                self?.presenter?.didReceive(dAppsResult: .success(result))
            } else {
                self?.presenter?.didReceive(dAppsResult: .success(nil))
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter?.didReceive(dAppsResult: .failure(error))
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        dAppProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }
}

extension DAppSearchInteractor: DAppSearchInteractorInputProtocol {
    func setup() {
        subscribeDApps()

        favoriteDAppsProvider = subscribeToFavoriteDApps(nil)
    }
}

extension DAppSearchInteractor: DAppLocalStorageSubscriber, DAppLocalSubscriptionHandler {
    func handleFavoriteDApps(result: Result<[DataProviderChange<DAppFavorite>], Error>) {
        switch result {
        case let .success(changes):
            presenter.didReceiveFavorite(changes: changes)
        case let .failure(error):
            logger.error("Favorites error: \(error)")
        }
    }
}
