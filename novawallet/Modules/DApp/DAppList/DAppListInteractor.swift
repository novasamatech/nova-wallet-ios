import Foundation
import RobinHood

final class DAppListInteractor {
    weak var presenter: DAppListInteractorOutputProtocol?

    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let dAppProvider: AnySingleValueProvider<DAppList>

    init(
        walletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        dAppProvider: AnySingleValueProvider<DAppList>
    ) {
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
        self.dAppProvider = dAppProvider
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
}

extension DAppListInteractor: DAppListInteractorInputProtocol {
    func setup() {
        provideAccountId()

        subscribeDApps()

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
