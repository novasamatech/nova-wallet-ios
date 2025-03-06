import Foundation
import Operation_iOS

final class BrowserNavigationInteractor {
    weak var presenter: BrowserNavigationInteractorOutputProtocol? {
        didSet {
            setup()
        }
    }

    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let dAppProvider: AnySingleValueProvider<DAppList>
    let dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol
    let dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>
    let logger: LoggerProtocol

    private var favoriteDAppsProvider: StreamableProvider<DAppFavorite>?

    init(
        walletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        dAppProvider: AnySingleValueProvider<DAppList>,
        dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol,
        dAppsFavoriteRepository: AnyDataProviderRepository<DAppFavorite>,
        logger: LoggerProtocol
    ) {
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
        self.dAppProvider = dAppProvider
        self.dAppsLocalSubscriptionFactory = dAppsLocalSubscriptionFactory
        self.dAppsFavoriteRepository = dAppsFavoriteRepository
        self.logger = logger
    }
}

// MARK: Private

private extension BrowserNavigationInteractor {
    func provideWallet() {
        guard let wallet = walletSettings.value else {
            return
        }

        presenter?.didReceive(walletResult: .success(wallet))
    }

    func subscribeDApps() {
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

// MARK: BrowserNavigationInteractorInputProtocol

extension BrowserNavigationInteractor: BrowserNavigationInteractorInputProtocol {
    func setup() {
        provideWallet()
        subscribeDApps()
        favoriteDAppsProvider = subscribeToFavoriteDApps(nil)
        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

// MARK: EventVisitorProtocol

extension BrowserNavigationInteractor: EventVisitorProtocol {
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        provideWallet()
    }
}

// MARK: DAppLocalStorageSubscriber

extension BrowserNavigationInteractor: DAppLocalStorageSubscriber, DAppLocalSubscriptionHandler {
    func handleFavoriteDApps(result: Result<[DataProviderChange<DAppFavorite>], Error>) {
        switch result {
        case let .success(changes):
            presenter?.didReceiveFavoriteDapp(changes: changes)
        case let .failure(error):
            logger.error("Unexpected favorites error: \(error)")
        }
    }
}
