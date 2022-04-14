import Foundation
import RobinHood

final class DAppListInteractor {
    weak var presenter: DAppListInteractorOutputProtocol?

    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let dAppProvider: AnySingleValueProvider<DAppList>
    let dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol
    let dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>
    let phishingSyncService: ApplicationServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var favoriteDAppsProvider: StreamableProvider<DAppFavorite>?

    init(
        walletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        dAppProvider: AnySingleValueProvider<DAppList>,
        phishingSyncService: ApplicationServiceProtocol,
        dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol,
        dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
        self.dAppProvider = dAppProvider
        self.phishingSyncService = phishingSyncService
        self.dAppsLocalSubscriptionFactory = dAppsLocalSubscriptionFactory
        self.dAppsFavoriteRepository = dAppsFavoriteRepository
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        phishingSyncService.throttle()
    }

    private func provideAccountId() {
        guard let wallet = walletSettings.value else {
            return
        }

        presenter?.didReceive(accountIdResult: .success(wallet.substrateAccountId))
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

    func addToFavorites(dApp: DApp) {
        let model = DAppFavorite(
            identifier: dApp.url.absoluteString,
            label: dApp.name,
            icon: dApp.icon?.absoluteString
        )

        let saveOperation = dAppsFavoriteRepository.saveOperation({ [model] }, { [] })

        operationQueue.addOperation(saveOperation)
    }

    func removeFromFavorites(dAppIdentifier: String) {
        let saveOperation = dAppsFavoriteRepository.saveOperation({ [] }, { [dAppIdentifier] })

        operationQueue.addOperation(saveOperation)
    }
}

extension DAppListInteractor: DAppListInteractorInputProtocol {
    func setup() {
        provideAccountId()

        subscribeDApps()

        favoriteDAppsProvider = subscribeToFavoriteDApps(nil)

        phishingSyncService.setup()

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    func refresh() {
        dAppProvider.refresh()
    }
}

extension DAppListInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        provideAccountId()
    }
}

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
