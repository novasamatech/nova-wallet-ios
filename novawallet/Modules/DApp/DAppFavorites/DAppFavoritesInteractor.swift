import UIKit
import Operation_iOS

final class DAppFavoritesInteractor {
    weak var presenter: DAppFavoritesInteractorOutputProtocol?

    let dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol
    let dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>
    let dAppProvider: AnySingleValueProvider<DAppList>
    let logger: LoggerProtocol

    let operationQueue: OperationQueue

    private var favoriteDAppsProvider: StreamableProvider<DAppFavorite>?

    init(
        presenter: DAppFavoritesInteractorOutputProtocol? = nil,
        dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol,
        dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>,
        dAppProvider: AnySingleValueProvider<DAppList>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.presenter = presenter
        self.dAppsLocalSubscriptionFactory = dAppsLocalSubscriptionFactory
        self.dAppsFavoriteRepository = dAppsFavoriteRepository
        self.dAppProvider = dAppProvider
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: Private

private extension DAppFavoritesInteractor {
    func subscribeDApps() {
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

    func createIndexUpdateOperation(
        _ favorites: [String: DAppFavorite],
        reorderedIds: [String]
    ) -> BaseOperation<[DAppFavorite]> {
        ClosureOperation {
            reorderedIds
                .enumerated()
                .compactMap { index, id in
                    favorites[id]?.updatingIndex(to: index)
                }
        }
    }
}

// MARK: DAppFavoritesInteractorInputProtocol

extension DAppFavoritesInteractor: DAppFavoritesInteractorInputProtocol {
    func setup() {
        favoriteDAppsProvider = subscribeToFavoriteDApps(nil)
        subscribeDApps()
    }

    func removeFavorite(with id: String) {
        let saveOperation = dAppsFavoriteRepository.saveOperation(
            { [] },
            { [id] }
        )

        operationQueue.addOperation(saveOperation)
    }

    func reorderFavorites(
        _ favorites: [String: DAppFavorite],
        reorderedIds: [String]
    ) {
        let indexUpdateOperation = createIndexUpdateOperation(
            favorites,
            reorderedIds: reorderedIds
        )
        let saveOperation = dAppsFavoriteRepository.saveOperation(
            { try indexUpdateOperation.extractNoCancellableResultData() },
            { [] }
        )

        saveOperation.addDependency(indexUpdateOperation)

        operationQueue.addOperations(
            [saveOperation, indexUpdateOperation],
            waitUntilFinished: false
        )
    }
}

// MARK: DAppLocalStorageSubscriber

extension DAppFavoritesInteractor: DAppLocalStorageSubscriber, DAppLocalSubscriptionHandler {
    func handleFavoriteDApps(result: Result<[DataProviderChange<DAppFavorite>], Error>) {
        switch result {
        case let .success(changes):
            presenter?.didReceiveFavorites(changes: changes)
        case let .failure(error):
            logger.error("Unexpected favorites error: \(error)")
        }
    }
}
