import UIKit
import RobinHood

final class DAppAuthSettingsInteractor {
    weak var presenter: DAppAuthSettingsInteractorOutputProtocol?

    let wallet: MetaAccountModel
    let dAppProvider: AnySingleValueProvider<DAppList>
    let authorizedDAppRepository: AnyDataProviderRepository<DAppSettings>
    let dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol
    let operationQueue: OperationQueue

    private var authorizedDAppsProvider: StreamableProvider<DAppSettings>?

    init(
        wallet: MetaAccountModel,
        dAppProvider: AnySingleValueProvider<DAppList>,
        dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol,
        authorizedDAppRepository: AnyDataProviderRepository<DAppSettings>,
        operationQueue: OperationQueue
    ) {
        self.wallet = wallet
        self.dAppProvider = dAppProvider
        self.dAppsLocalSubscriptionFactory = dAppsLocalSubscriptionFactory
        self.authorizedDAppRepository = authorizedDAppRepository
        self.operationQueue = operationQueue
    }

    private func subscribeDApps() {
        let updateClosure: ([DataProviderChange<DAppList>]) -> Void = { [weak self] changes in
            let result = changes.reduceToLastChange()
            self?.presenter?.didReceiveDAppList(result)
        }

        let failureClosure: (Error) -> Void = { [weak self] _ in
            self?.presenter?.didReceive(error: CommonError.databaseSubscription)
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

extension DAppAuthSettingsInteractor: DAppAuthSettingsInteractorInputProtocol {
    func setup() {
        subscribeDApps()
        authorizedDAppsProvider = subscribeToAuthorizedDApps(by: wallet.metaId)
    }

    func remove(auth: DAppSettings) {
        let removeOperation = authorizedDAppRepository.saveOperation({ [] }, { [auth.identifier] })
        operationQueue.addOperation(removeOperation)
    }
}

extension DAppAuthSettingsInteractor: DAppLocalStorageSubscriber, DAppLocalSubscriptionHandler {
    func handleAuthorizedDApps(result: Result<[DataProviderChange<DAppSettings>], Error>, for _: String) {
        switch result {
        case let .success(changes):
            presenter?.didReceiveAuthorizationSettings(changes: changes)
        case let .failure(error):
            presenter?.didReceive(error: error)
        }
    }
}
