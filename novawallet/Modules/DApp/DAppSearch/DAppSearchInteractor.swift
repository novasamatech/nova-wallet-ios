import Foundation
import RobinHood

final class DAppSearchInteractor {
    weak var presenter: DAppSearchInteractorOutputProtocol!

    let dAppProvider: AnySingleValueProvider<DAppList>

    init(dAppProvider: AnySingleValueProvider<DAppList>) {
        self.dAppProvider = dAppProvider
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
    }
}
