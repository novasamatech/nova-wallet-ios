import Foundation
import Operation_iOS

final class DAppListInteractor {
    weak var presenter: DAppListInteractorOutputProtocol?

    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let dAppProvider: AnySingleValueProvider<DAppList>
    let dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol
    let dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>
    let phishingSyncService: ApplicationServiceProtocol
    let logger: LoggerProtocol
    let walletNotificationService: WalletNotificationServiceProtocol

    private var favoriteDAppsProvider: StreamableProvider<DAppFavorite>?

    init(
        walletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        dAppProvider: AnySingleValueProvider<DAppList>,
        phishingSyncService: ApplicationServiceProtocol,
        dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol,
        dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>,
        walletNotificationService: WalletNotificationServiceProtocol,
        logger: LoggerProtocol
    ) {
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
        self.dAppProvider = dAppProvider
        self.phishingSyncService = phishingSyncService
        self.dAppsLocalSubscriptionFactory = dAppsLocalSubscriptionFactory
        self.dAppsFavoriteRepository = dAppsFavoriteRepository
        self.walletNotificationService = walletNotificationService
        self.logger = logger
    }

    deinit {
        phishingSyncService.throttle()
    }

    private func provideWallet() {
        guard let wallet = walletSettings.value else {
            return
        }

        presenter?.didReceive(walletResult: .success(wallet))
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
        provideWallet()

        subscribeDApps()

        favoriteDAppsProvider = subscribeToFavoriteDApps(nil)

        phishingSyncService.setup()

        eventCenter.add(observer: self, dispatchIn: .main)

        walletNotificationService.hasUpdatesObservable.addObserver(
            with: self,
            sendStateOnSubscription: true
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveWalletsState(hasUpdates: newState)
        }
    }

    func refresh() {
        dAppProvider.refresh()
    }
}

// MARK: EventVisitorProtocol

extension DAppListInteractor: EventVisitorProtocol {
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        provideWallet()
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
